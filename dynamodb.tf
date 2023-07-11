#####################################################################################################################################################################
###
### Summary : DynamoDB
###
#####################################################################################################################################################################
# - Resource
#   - main
#     - table

#####################################################################################################################################################################
###
### Parameter
###
#####################################################################################################################################################################
locals {
  dynamodb_table = {
    user_table = {
      name                          = "User-Table"
      billing_mode                  = "PAY_PER_REQUEST"
      hash_key                      = "UserId"
      range_key                     = "ProfileId" 
      attributes = {
        UserId = {
          type                      = "N"
        }
        ProfileId = {
          type                      = "N"
        }
      }
      point_in_time_recovery        = true
      newrelic                      = "${ var.env == "prd" ? "enabled" : "disabled"}"
      billing                       = "${ var.env == "prd" ? "3" : "0"}"
    }
    comment_table = {
      name                          = "Comment-Table"
      billing_mode                  = "PAY_PER_REQUEST"
      hash_key                      = "CommentId"
      range_key                     = "CreatedAt" 
      attributes = {
        CommentId = {
          type                      = "N"
        }
        CreatedAt = {
          type                      = "N"
        }
      }
      point_in_time_recovery        = true
      newrelic                      = "${ var.env == "prd" ? "enabled" : "disabled"}"
      billing                       = "${ var.env == "prd" ? "3" : "0"}"
    }
  }
}

#####################################################################################################################################################################
###
### main
###
#####################################################################################################################################################################

################################################
### Table
################################################
resource "aws_dynamodb_table" "this" {
  for_each = local.dynamodb_table

  name                    = "${var.project_name}-${var.env}-${each.value.name}"
  billing_mode            = each.value.billing_mode
  hash_key                = each.value.hash_key
  range_key               = each.value.range_key

  point_in_time_recovery  {
    enabled = each.value.point_in_time_recovery
  }

  dynamic "attribute" {
    for_each = each.value.attributes

    content {
      name = attribute.key
      type = attribute.value.type
    }

  }

  tags = {
    Name                  = "${var.project_name}-${var.env}-${each.key}"
    cloudpack_newrelic    = each.value.newrelic
    IRET_BILLING_SERVICE  = each.value.billing
  }
}