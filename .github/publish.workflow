workflow "Publish images to Docker hub" {
  on = "push"
  resolves = ["commit"]
}

action "Update Dockerfile and scripts for all versions" {
  uses = "bash"
  runs = "./update.sh"
}

action "Auto-commit" {
  uses = "docker://cdssnc/auto-commit-github-action"
  needs = ["Update Dockerfile and scripts for all versions"]
  args = "auto-commit updated Dockerfile and scripts for all versions"
  secrets = ["GITHUB_TOKEN"]
}
