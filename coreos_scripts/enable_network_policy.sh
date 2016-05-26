curl -H "Content-Type: application/json" -XPOST http://127.0.0.1:8080/apis/extensions/v1beta1/namespaces/default/thirdpartyresources --data-binary  @- <<BODY
{
  "kind": "ThirdPartyResource",
  "apiVersion": "extensions/v1beta1",
  "metadata": {
    "name": "network-policy.net.alpha.kubernetes.io"
  },
  "description": "Specification for a network isolation policy",
  "versions": [
    {
      "name": "v1alpha1"
    }
  ]
}
BODY
