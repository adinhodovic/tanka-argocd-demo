{
  local container = $.core.v1.container,
  local containerPort = $.core.v1.containerPort,
  echo_container::
    container.new('echo', 'k8s.gcr.io/echoserver:1.4') +
    container.withPorts(containerPort.new('http', 8080)),

  local deployment = $.apps.v1.deployment,
  echo_deployment:
    deployment.new('echo', 1, [self.echo_container]),

  echo_service:
    $.util.serviceFor(self.echo_deployment),
}
