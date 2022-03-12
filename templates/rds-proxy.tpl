{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "GetSecretValue",
            "Action": [
                "secretsmanager:GetResourcePolicy",
                "secretsmanager:GetSecretValue",
                "secretsmanager:DescribeSecret",
                "secretsmanager:ListSecretVersionIds"
            ],
            "Effect": "Allow",
            "Resource": [
                "${secret_arn}"
            ]
        },
        {
            "Sid": "DecryptSecretValue",
            "Action": [
                "kms:Decrypt"
            ],
            "Effect": "Allow",
            "Resource": [
                "${key_arn}"
            ],
            "Condition": {
                "StringEquals": {
                    "kms:ViaService": "secretsmanager.${region}.amazonaws.com"
                }
            }
        }
    ]
}

