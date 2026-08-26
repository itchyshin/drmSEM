# Register imputed.drm_sem on drmTMB's generic when the engine is present, so
# library(drmTMB); library(drmSEM) and the reverse both dispatch.
.onLoad <- function(libname, pkgname) {
  if (requireNamespace("drmTMB", quietly = TRUE)) {
    registerS3method(
      "imputed",
      "drm_sem",
      imputed.drm_sem,
      envir = asNamespace("drmTMB")
    )
  }
}
