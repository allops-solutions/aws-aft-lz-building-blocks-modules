###############################################################################
# Buildspec file references
#
# Real YAML files under assets/buildspecs/, loaded via data "local_file".
###############################################################################

data "local_file" "buildspec_plan" {
  filename = "${path.module}/assets/buildspecs/buildspec-plan.yml"
}

data "local_file" "buildspec_apply" {
  filename = "${path.module}/assets/buildspecs/buildspec-apply.yml"
}

data "local_file" "buildspec_combined" {
  filename = "${path.module}/assets/buildspecs/buildspec-combined.yml"
}
