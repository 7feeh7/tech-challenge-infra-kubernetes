resource "datadog_synthetics_test" "api_health" {
  count = var.datadog_app_key != "" ? 1 : 0

  name      = "[Tech Challenge] Health ${var.environment}"
  type      = "api"
  subtype   = "http"
  status    = "live"
  message   = "Healthcheck publico indisponivel. ${var.datadog_alert_recipients}"
  locations = ["aws:us-east-1"]

  tags = [
    "env:${var.environment}",
    "service:${local.dd_service}",
  ]

  request_definition {
    method = "GET"
    url    = "${aws_apigatewayv2_api.main.api_endpoint}/health"
  }

  assertion {
    type     = "statusCode"
    operator = "is"
    target   = "200"
  }

  assertion {
    type     = "responseTime"
    operator = "lessThan"
    target   = "3000"
  }

  options_list {
    tick_every           = 300
    monitor_priority     = 2
    min_failure_duration = 0
    min_location_failed  = 1

    retry {
      count    = 2
      interval = 300
    }
  }
}
