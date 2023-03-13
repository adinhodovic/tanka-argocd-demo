{
  // Plugin specific configs
  local tankaVersion = 'v0.20.0',
  local jsonnetBundlerVersion = 'v0.5.1',
  local pluginDir = '/home/argocd/cmp-server/plugins',

  argoCdChart: {
    helmApplication: {
      apiVersion: 'argoproj.io/v1alpha1',
      kind: 'Application',
      metadata: {
        name: 'argo-cd',
        namespace: 'default',
      },
      spec: {
        project: 'default',
        destination: {
          namespace: 'default',
          server: 'https://kubernetes.default.svc',
        },
        source: {
          chart: 'argo-cd',
          repoURL: 'https://argoproj.github.io/argo-helm',
          targetRevision: '5.20.0',
          helm: {
            releaseName: 'argo-cd',
            values: |||
              %s
            ||| % std.manifestYamlDoc(
              {
                configs: {
                  params: {
                    'server.insecure': true,
                    'server.disable.auth': true,
                  },
                },
                repoServer: {
                  clusterAdminAccess: {
                    enabled: true,
                  },
                  extraContainers: [
                    {
                      name: 'cmp',
                      image: 'curlimages/curl',

                      local jsonnetBundlerCurlCommand = 'curl -Lo %s/jb https://github.com/jsonnet-bundler/jsonnet-bundler/releases/download/%s/jb-linux-amd64' % [pluginDir, jsonnetBundlerVersion],
                      local tankaCurlCommand = 'curl -Lo %s/tk https://github.com/grafana/tanka/releases/download/%s/tk-linux-amd64' % [pluginDir, tankaVersion],
                      local chmodCommands = 'chmod +x %s/jb && chmod +x %s/tk' % [pluginDir, pluginDir],
                      command: [
                        'sh',
                        '-c',
                        '%s && %s && %s && /var/run/argocd/argocd-cmp-server' % [jsonnetBundlerCurlCommand, tankaCurlCommand, chmodCommands],
                      ],
                      securityContext: {
                        runAsNonRoot: true,
                        runAsUser: 999,
                      },
                      volumeMounts: [
                        {
                          mountPath: '/var/run/argocd',
                          name: 'var-files',
                        },
                        {
                          mountPath: pluginDir,
                          name: 'plugins',
                        },
                        {
                          mountPath: '/home/argocd/cmp-server/config/plugin.yaml',
                          subPath: 'plugin.yaml',
                          name: 'cmp-plugin',
                        },
                      ],
                    },
                  ],
                  volumes: [
                    {
                      configMap: {
                        name: 'cmp-plugin',
                      },
                      name: 'cmp-plugin',
                    },
                    {
                      emptyDir: {},
                      name: 'cmp-tmp',
                    },
                  ],
                },
              }
            ),
          },
        },
      },
    },
  },

  argoCdPlugin: {
    apiVersion: 'v1',
    kind: 'ConfigMap',
    metadata: {
      name: 'cmp-plugin',
      namespace: 'default',
    },
    data: {
      'plugin.yaml': |||
        %s
      ||| % std.manifestYamlDoc({
        apiVersion: 'argoproj.io/v1alpha1',
        kind: 'ConfigManagementPlugin',
        metadata: {
          name: 'tanka',
          namespace: 'default',
        },
        spec: {
          version: tankaVersion,
          init: {
            command: [
              'sh',
              '-c',
              '%s/jb install' % pluginDir,
            ],
          },
          generate: {
            command: [
              'sh',
              '-c',
              '%s/tk show environments/${ARGOCD_ENV_TK_ENV} --dangerous-allow-redirect' % pluginDir,
            ],
          },
          discover: {
            fileName: '*',
          },
        },
      }),
    },
  },

  defaultApplication: {
    apiVersion: 'argoproj.io/v1alpha1',
    kind: 'Application',
    metadata: {
      name: 'default',
    },
    spec: {
      project: 'default',
      source: {
        repoURL: 'https://github.com/adinhodovic/tanka-argocd-demo',
        path: 'tanka',
        targetRevision: 'HEAD',
        plugin: {
          env: [
            {
              name: 'TK_ENV',
              value: 'default',
            },
          ],
        },
      },
      destination: {
        server: 'https://kubernetes.default.svc',
      },
      syncPolicy: {
        automated: {
          prune: true,
          selfHeal: true,
        },
      },
    },
  },

  defaultProject: {
    apiVersion: 'argoproj.io/v1alpha1',
    kind: 'AppProject',
    metadata: {
      name: 'default',
      namespace: 'default',
      finalizers: [
        'resources-finalizer.argocd.argoproj.io',
      ],
    },
    spec: {
      description: 'MyOrg Default AppProject',
      sourceRepos: [
        '*',
      ],
      clusterResourceWhitelist: [
        {
          group: '*',
          kind: '*',
        },
      ],
      destinations: [
        {
          namespace: '*',
          server: '*',
        },
      ],
    },
  },
}
