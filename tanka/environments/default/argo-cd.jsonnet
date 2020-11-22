{
  local _config = {
    name: 'argo-cd',
    repo_server_service_account: 'argo-cd-demo-repo-server',
  },

  argo_cd: {

    helm_release: {
      kind: 'HelmRelease',
      apiVersion: 'helm.fluxcd.io/v1',
      metadata: {
        name: _config.name,
      },
      spec: {
        chart: {
          repository: 'https://argoproj.github.io/argo-helm',
          version: '2.9.3',
          name: _config.name,
        },
        releaseName: _config.name,
        values: {
          nameOverride: 'argo-cd-demo',
          server: {
            extraArgs: [
              '--disable-auth',
              '--insecure',

            ],
            config: {
              repositories: std.manifestYamlDoc(
                [
                  {
                    url: 'https://github.com/adinhodovic/tanka-argocd-demo',
                    passwordSecret: {
                      name: 'argo-cd-git',
                      key: 'password',
                    },
                    usernameSecret: {
                      name: 'argo-cd-git',
                      key: 'username',
                    },
                  },
                ],
              ),
              configManagementPlugins: std.manifestYamlDoc(
                [
                  {
                    name: 'tanka',
                    init: {
                      command: [
                        'sh',
                        '-c',
                      ],
                      args: [
                        'jb install',
                      ],
                    },
                    generate: {
                      command: [
                        'sh',
                        '-c',
                      ],
                      args: [
                        'tk show environments/${TK_ENV} --dangerous-allow-redirect ${EXTRA_ARGS}',
                      ],
                    },
                  },
                ],

              ),
            },
          },
          repoServer: {
            serviceAccount: {
              name: _config.repo_server_service_account,
            },
            volumes: [
              {
                name: 'custom-tools',
                emptyDir: {},
              },
            ],
            initContainers: [
              {
                name: 'download-tools',
                image: 'curlimages/curl',
                command: [
                  'sh',
                  '-c',
                ],
                args: [
                  'curl -Lo /custom-tools/jb https://github.com/jsonnet-bundler/jsonnet-bundler/releases/latest/download/jb-linux-amd64 && curl -Lo /custom-tools/tk https://github.com/grafana/tanka/releases/download/v0.12.0/tk-linux-amd64 && chmod +x /custom-tools/tk && chmod +x /custom-tools/jb',
                ],
                volumeMounts: [
                  {
                    mountPath: '/custom-tools',
                    name: 'custom-tools',
                  },
                ],
              },
            ],
            volumeMounts: [
              {
                mountPath: '/usr/local/bin/jb',
                name: 'custom-tools',
                subPath: 'jb',
              },
              {
                mountPath: '/usr/local/bin/tk',
                name: 'custom-tools',
                subPath: 'tk',
              },
            ],
          },
        },
      },
    },

    local serviceAccount = $.core.v1.serviceAccount,
    service_account:
      serviceAccount.new(_config.repo_server_service_account),

    local clusterRole = $.rbac.v1.clusterRole,
    local policyRule = $.rbac.v1beta1.policyRule,
    cluster_role:
      clusterRole.new() +
      clusterRole.mixin.metadata.withName(_config.repo_server_service_account) +
      clusterRole.withRulesMixin([
        policyRule.new() +
        policyRule.withApiGroups('*') +
        policyRule.withResources(['*']) +
        policyRule.withVerbs(['*']),
      ]),

    local clusterRoleBinding = $.rbac.v1.clusterRoleBinding,
    cluster_role_binding:
      clusterRoleBinding.new() +
      clusterRoleBinding.mixin.metadata.withName(_config.repo_server_service_account) +
      clusterRoleBinding.mixin.roleRef.withApiGroup('rbac.authorization.k8s.io') +
      clusterRoleBinding.mixin.roleRef.withKind('ClusterRole') +
      clusterRoleBinding.mixin.roleRef.withName(_config.repo_server_service_account) +
      clusterRoleBinding.withSubjectsMixin({
        kind: 'ServiceAccount',
        name: _config.repo_server_service_account,
        namespace: 'default',
      }),

    default_app_project: {
      apiVersion: 'argoproj.io/v1alpha1',
      kind: 'AppProject',
      metadata: {
        name: 'default',
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

    default_application: {
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
            name: 'tanka',
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
  },
}
