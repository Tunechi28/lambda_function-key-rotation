data "archive_file" "lambda_package" {
  type        = "zip"
  source_file = "${path.module}/Lambda_rotation.py"
  output_path = "${path.module}/Lambda_package.zip"
}

###############################
#Create VPC for  infrastructure
###############################

resource "aws_vpc" "main" {
    cidr_block      = var.cidr_block

    tags = {
        "Name"      = "VPC for lambda"
    }
}

# Connect to the internet via IGW

resource "aws_internet_gateway" "main" {
    vpc_id          = aws_vpc.main.id

    tags = {
        "Name"      = "IGW for lambda"
    }
}

# Create a public subnet

resource "aws_subnet" "public" {
    count           = 1
    vpc_id          = aws_vpc.main.id
    cidr_block      = cidrsubnet(var.cidr_block, 1, count.index)
    availability_zone = "us-east-1a"
    map_public_ip_on_launch = true

    tags = {
        "Name"      = "Public Subnet"
    }
}


########################
# Create role for lambda
########################

resource "aws_iam_role" "lambda_role" {
  name = "lambda_role_for_key_rotation"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      }
    }
  ]
}
EOF
}


#########################
# create a SNS Sns topic
#########################

resource "aws_sns_topic" "key_creation" {
  name = "new key creation"
}

##########################
# Create a lambda function
##########################

resource "aws_lambda_function" "key_rotation" {
  provider = aws.a112-r5
  filename         = data.archive_file.lambda_package.output_path
  function_name    = "key_rotation"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_handler"
  source_code_hash = filebase64sha256(data.archive_file.lambda_package.output_path)
  memory_size      = 128
  timeout          = 10
  runtime = "python3.8"
  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.sns_topic.arn
    }
  }
}

resource "aws_cloudwatch_log_group" "lambda_wg" {
    name            = "the_watch_group"
    retention_in_days = 14
}

# create policy: AWSLambdaBasicExecutionRole
resource "aws_iam_policy" "lambda_logging" {
    name            = "lambda_logging"
    path            = "/"
    description     = "IAM policy for logging from lambda"

    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}



# Permission for CloudWatch
resource "aws_lambda_permission" "cloudwatch" {
    statement_id    = "AllowExecutionFromCloudWatch"
    action          = "lambda:InvokeFunction"
    function_name   = aws_lambda_function.key_rotation.function_name
    principal       = "events.amazonaws.com"
    source_arn      = "arn:aws:events:eu-west-1:111122223333:rule/RunDaily"
}