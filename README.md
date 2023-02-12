# GitOps with ArgoCD and Tanka

A simple demo on how to use Tanka with ArgoCD, a detailed blog post can be found [on my blog](https://hodovi.cc/blog/gitops-argocd-and-tanka/).

### Update 13/02/2023

This blog post has been adjusted to ArgoCD's v2.6 deprecation of plugin usage within the ArgoCD repo server container. This was done due to security reasons. Instead, plugins should be running in a sidecar that has all the tools needed to generate manifest. The repository has been updated as well. If you would like to see the previous configuration that does not use the sidecar plugin setup check the GitHub repository commit history.
