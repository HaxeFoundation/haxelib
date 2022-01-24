resource "aws_cloudfront_distribution" "lib-haxe-org" {
  aliases         = ["lib.haxe.org"]
  enabled         = true
  is_ipv6_enabled = true
  price_class     = "PriceClass_100"

  origin {
    domain_name = "lib.haxe.org"
    origin_id   = "Custom-master-lib.haxe.org"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols = [
        "TLSv1",
        "TLSv1.1",
        "TLSv1.2"
      ]
    }
  }

  origin {
    domain_name = "lib.haxe.org.s3.amazonaws.com"
    origin_id   = "S3-lib.haxe.org"
  }

  ordered_cache_behavior {
    path_pattern     = "files/*"
    target_origin_id = "S3-lib.haxe.org"
    allowed_methods = [
      "HEAD",
      "GET",
    ]
    cached_methods = [
      "HEAD",
      "GET",
    ]
    forwarded_values {
      headers                 = []
      query_string            = false
      query_string_cache_keys = []
      cookies {
        forward           = "none"
        whitelisted_names = []
      }
    }
    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
  }

  ordered_cache_behavior {
    path_pattern     = "api/*"
    target_origin_id = "Custom-master-lib.haxe.org"
    allowed_methods = [
      "HEAD",
      "DELETE",
      "POST",
      "GET",
      "OPTIONS",
      "PUT",
      "PATCH"
    ]
    cached_methods = [
      "HEAD",
      "GET",
    ]
    forwarded_values {
      headers                 = ["*"]
      query_string            = true
      query_string_cache_keys = []
      cookies {
        forward           = "all"
        whitelisted_names = []
      }
    }
    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
  }

  ordered_cache_behavior {
    path_pattern     = "index.n"
    target_origin_id = "Custom-master-lib.haxe.org"
    allowed_methods = [
      "HEAD",
      "DELETE",
      "POST",
      "GET",
      "OPTIONS",
      "PUT",
      "PATCH"
    ]
    cached_methods = [
      "HEAD",
      "GET",
    ]
    forwarded_values {
      headers                 = ["*"]
      query_string            = true
      query_string_cache_keys = []
      cookies {
        forward           = "all"
        whitelisted_names = []
      }
    }
    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
  }

  default_cache_behavior {
    target_origin_id       = "Custom-master-lib.haxe.org"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods = [
      "HEAD",
      "DELETE",
      "POST",
      "GET",
      "OPTIONS",
      "PUT",
      "PATCH",
    ]
    cached_methods = [
      "HEAD",
      "GET",
    ]
    forwarded_values {
      headers                 = []
      query_string            = true
      query_string_cache_keys = []
      cookies {
        forward           = "none"
        whitelisted_names = []
      }
    }
    compress    = true
    min_ttl     = 0
    default_ttl = 86400
    max_ttl     = 31536000
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
