#!/usr/bin/env Rscript
# Run from the setharielgreen project root:  Rscript update_hugo.R
# Installs the latest Hugo release, re-pins netlify.toml + .Rprofile to
# match, and rebuilds the site as a smoke test. Reverts the pin if the
# new version breaks the build, so a bad release can't get committed silently.

stopifnot(file.exists("netlify.toml"), file.exists(".Rprofile"))

rprofile_orig <- readLines(".Rprofile")
netlify_orig <- readLines("netlify.toml")

old_version <- sub(
  ".*blogdown\\.hugo\\.version = '([0-9.]+)'.*", "\\1",
  grep("blogdown\\.hugo\\.version", rprofile_orig, value = TRUE)
)

new_version <- sub("^v", "", xfun::github_releases("gohugoio/hugo", "latest")[1])

if (identical(new_version, old_version)) {
  message("Already pinned to the latest Hugo release (", old_version, "). Nothing to do.")
  quit(save = "no")
}

message("Updating Hugo pin: ", old_version, " -> ", new_version)
blogdown::install_hugo(new_version)

writeLines(gsub(old_version, new_version, rprofile_orig, fixed = TRUE), ".Rprofile")
writeLines(gsub(old_version, new_version, netlify_orig, fixed = TRUE), "netlify.toml")

build_ok <- tryCatch(
  {
    blogdown::build_site(build_rmd = FALSE)
    TRUE
  },
  error = function(e) {
    message("Build failed with Hugo ", new_version, ": ", conditionMessage(e))
    FALSE
  }
)

if (build_ok) {
  message(
    "Build succeeded with Hugo ", new_version,
    ". Pin updated -- review the diff and commit when ready."
  )
} else {
  message("Reverting pin to ", old_version, ".")
  writeLines(rprofile_orig, ".Rprofile")
  writeLines(netlify_orig, "netlify.toml")
}
