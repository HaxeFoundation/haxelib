# Gateway API routes for haxelib. They replaced the ingress-nginx Ingresses in Nov 2026.
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
        # Apache's mod_status page (apache2.conf) shows the requests being served, so keep it private.
        # The readiness probes and the image's HEALTHCHECK call the pod directly, not through the Gateway.
        # The backend is never called (the filter returns first), but NGF needs one to generate a normal location.
        {
          matches = [{
            path = {
              type  = "PathPrefix"
              value = "/httpd-status"
            }
          }]
          filters = [{
            type = "ExtensionRef"
            extensionRef = {
              group = "gateway.nginx.org"
              kind  = "SnippetsFilter"
              name  = kubernetes_manifest.do-haxelib-server-not-found.manifest.metadata.name
            }
          }]
          backendRefs = [{
            name = kubernetes_service_v1.do-haxelib-server[each.key].metadata[0].name
            port = 80
          }]
        },
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

# Responds 404 without calling the backend. Used to hide paths that must not be public.
resource "kubernetes_manifest" "do-haxelib-server-not-found" {
  manifest = {
    apiVersion = "gateway.nginx.org/v1alpha1"
    kind       = "SnippetsFilter"
    metadata = {
      name      = "haxelib-server-not-found"
      namespace = "default"
    }
    spec = {
      snippets = [{
        context = "http.server.location"
        value   = "return 404;"
      }]
    }
  }
}
