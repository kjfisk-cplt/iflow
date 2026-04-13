locals {
  tags = module.naming.common_tags

  # Environment suffix for Action Group (uppercase)
  env_suffix = upper(var.env)
}
