data "aws_region" "current" {}

locals {
  is_not_windows = contains(["LINUX"], var.operating_system_family)

  log_group_name = "/aws/ecs/${var.service}/${var.name}"

  log_configuration = merge(
    { for k, v in {
      logDriver = "awslogs",
      options = {
        awslogs-region        = data.aws_region.current.name,
        awslogs-group         = try(aws_cloudwatch_log_group.this[0].name, ""),
        awslogs-stream-prefix = "ecs"
      },
    } : k => v if var.enable_cloudwatch_logging },
    var.log_configuration
  )

  linux_parameters = var.enable_execute_command ? merge({ "initProcessEnabled" : true }, var.linux_parameters) : merge({ "initProcessEnabled" : false }, var.linux_parameters)

  health_check = length(var.health_check) > 0 ? merge({
    interval = 30,
    retries  = 3,
    timeout  = 5
  }, var.health_check) : null

  definition = {
    command                  = length(var.command) > 0 ? var.command : null
    cpu                      = var.cpu
    dependencies             = length(var.dependencies) > 0 ? var.dependencies : null # depends_on is a reserved word
    disable_networking       = local.is_not_windows ? var.disable_networking : null
    dns_search_domains       = local.is_not_windows && length(var.dns_search_domains) > 0 ? var.dns_search_domains : null
    dns_servers              = local.is_not_windows && length(var.dns_servers) > 0 ? var.dns_servers : null
    docker_labels            = length(var.docker_labels) > 0 ? var.docker_labels : null
    docker_security_options  = length(var.docker_security_options) > 0 ? var.docker_security_options : null
    entrypoint               = length(var.entrypoint) > 0 ? var.entrypoint : null
    environment              = var.environment
    environment_files        = length(var.environment_files) > 0 ? var.environment_files : null
    essential                = var.essential
    extra_hosts              = local.is_not_windows && length(var.extra_hosts) > 0 ? var.extra_hosts : null
    firelens_configuration   = length(var.firelens_configuration) > 0 ? var.firelens_configuration : null
    health_check             = local.health_check
    hostname                 = var.hostname
    image                    = var.image
    interactive              = var.interactive
    links                    = local.is_not_windows && length(var.links) > 0 ? var.links : null
    linux_parameters         = local.is_not_windows && length(local.linux_parameters) > 0 ? local.linux_parameters : null
    log_configuration        = length(local.log_configuration) > 0 ? local.log_configuration : null
    memory                   = var.memory
    memory_reservation       = var.memory_reservation
    mount_points             = var.mount_points
    name                     = var.name
    port_mappings            = var.port_mappings
    privileged               = local.is_not_windows ? var.privileged : null
    pseudo_terminal          = var.pseudo_terminal
    readonly_root_filesystem = local.is_not_windows ? var.readonly_root_filesystem : null
    repository_credentials   = length(var.repository_credentials) > 0 ? var.repository_credentials : null
    resource_requirements    = length(var.resource_requirements) > 0 ? var.resource_requirements : null
    secrets                  = length(var.secrets) > 0 ? var.secrets : null
    start_timeout            = var.start_timeout
    stop_timeout             = var.stop_timeout
    system_controls          = length(var.system_controls) > 0 ? var.system_controls : null
    ulimits                  = local.is_not_windows && length(var.ulimits) > 0 ? var.ulimits : null
    user                     = local.is_not_windows ? var.user : null
    volumes_from             = var.volumes_from
    working_directory        = var.working_directory
  }

  # Strip out all null values, ECS API will provide defaults in place of null/empty values
  container_definition = { for k, v in local.definition : k => v if v != null }
}

resource "aws_cloudwatch_log_group" "this" {
  count = var.create_cloudwatch_log_group && var.enable_cloudwatch_logging ? 1 : 0

  name              = var.cloudwatch_log_group_use_name_prefix ? null : local.log_group_name
  name_prefix       = var.cloudwatch_log_group_use_name_prefix ? "${local.log_group_name}-" : null
  retention_in_days = var.cloudwatch_log_group_retention_in_days
  kms_key_id        = var.cloudwatch_log_group_kms_key_id

  tags = var.tags
}
