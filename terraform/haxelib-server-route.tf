# Gateway API routes for haxelib, replacing the three Ingresses per stage
# (do-haxelib-server, do-haxelib-server-api, do-haxelib-server-files).
#
# The Gateway, its listeners and certificates, and the "proxy-cache" SnippetsFilter are defined in
# https://github.com/HaxeFoundation/haxe-terraform (do-k8s-gateway.tf).
resource "kubernetes_manifest" "do-haxelib-server-route" {
  for_each = local.haxelib_server.stage

  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "haxelib-server-${each.key}"
      namespace = "default"
    }
    spec = {
      # Attach to both HTTP and HTTPS. HTTP is not redirected to HTTPS at the gateway:
      # old haxelib clients use plain HTTP, and the Apache in the haxelib server container handles redirects.
      parentRefs = [
        for listener in ["http", "https-lib-${each.key}"] : {
          group       = "gateway.networking.k8s.io"
          kind        = "Gateway"
          name        = "haxe"
          namespace   = "nginx-gateway"
          sectionName = listener
        }
      ]
      hostnames = [each.value.host]
      # The longest matching path prefix wins, as with the Ingresses.
      rules = [
        {
          matches = [{
            path = {
              type  = "PathPrefix"
              value = "/api/3.0/index.n"
            }
          }]
          backendRefs = [{
            name = kubernetes_service_v1.do-haxelib-server-api[each.key].metadata[0].name
            port = 80
          }]
        },
        {
          matches = [{
            path = {
              type  = "PathPrefix"
              value = "/files/3.0"
            }
          }]
          backendRefs = [{
            name = kubernetes_service_v1.do-haxelib-server-files[each.key].metadata[0].name
            port = 80
          }]
        },
        {
          matches = [{
            path = {
              type  = "PathPrefix"
              value = "/"
            }
          }]
          filters = [{
            type = "ExtensionRef"
            extensionRef = {
              group = "gateway.nginx.org"
              kind  = "SnippetsFilter"
              name  = "proxy-cache"
            }
          }]
          backendRefs = [{
            name = kubernetes_service_v1.do-haxelib-server[each.key].metadata[0].name
            port = 80
          }]
        },
      ]
    }
  }
}
