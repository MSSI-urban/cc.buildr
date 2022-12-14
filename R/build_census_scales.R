#' Build census scales
#'
#' @param master_polygon <`sfc_MULTIPOLYGON`>. Unioned multipolygon of all the
#' geometries for which census data must be gathered.
#' @param census_dataset <`character`> The dataset to query for available
#' regions, e.g. \code{"CA16"}. Defaults to \code{\link[cc.buildr]{current_census}}.
#' @param regions <`named list`> A named list of census regions to retrieve.
#' Names must be valid census aggregation levels. Preferably a whole province
#' to make sure all geometries present in the <`master_polygon`> is added.
#' e.g. \code{list(PR = 24)} for Montreal.
#' @param levels <`character`> The census aggregation levels to retrieve.
#' Can be \code{"CMA"}, \code{"CD"}, \code{"CT"}, \code{"DA"}, \code{"DB"}, ...
#' @param crs <`numeric`> EPSG coordinate reference system to be assigned, e.g.
#' \code{32618} for Montreal.
#' @param fill_CTs_with_CSDs <`logical`> If the master polygon is bigger than a
#' CMA, should what is outside the CMA display the CSDs on the CT scale?
#' @param override_name_2 <`named list`> Override name_2. Defaults to name_2 for
#' CSDs being "City" with \code{list(CSD = "City")}, e.g. the display on Curbcut
#' for CSDs would then be e.g. `City of Laval`. For scales below CSD, the name
#' of the CSD in which the zone is gets the CSD name as their name_2. The
#' default display for a CT would then be e.g. `Census tract 4620633.00 (Laval)`.
#'
#' @return A list of sf dataframes of census scales filtered by the master polygon,
#' with the option of one CSD subdivided.
#' @export
build_census_scales <- function(master_polygon,
                                census_dataset = cc.buildr::current_census,
                                regions,
                                levels = c("CSD", "CT", "DA"), crs,
                                fill_CTs_with_CSDs = TRUE,
                                override_name_2 = list(CSD = "City")) {
  # Get census data with the help of cc.buildr::get_census_cc()
  census_datasets <-
    sapply(levels, \(x) {
      get_census_cc(
        master_polygon = master_polygon,
        census_dataset = census_dataset,
        regions = regions,
        level = x,
        crs = crs
      )
    }, simplify = FALSE, USE.NAMES = TRUE)

  # Rename `name` so they don't include the parenthesis
  census_datasets <-
    lapply(census_datasets, \(x) {
      x$name <- gsub(" \\(.*\\)$", "", x$name)
      x
    })

  # If the master polygon is bigger than a CMA, then there are gaps that need
  # to be fill with CSDs.
  if (fill_CTs_with_CSDs) {
    csds <- sf::st_transform(census_datasets$CSD, crs)
    csds <- suppressWarnings(sf::st_point_on_surface(csds))
    cts <- sf::st_transform(census_datasets$CT, crs)
    csds_in_cts <- sf::st_filter(csds, cts)$ID

    csds_to_bind <-
      census_datasets$CSD[!census_datasets$CSD$ID %in% csds_in_cts, ]

    if (nrow(csds_to_bind) != 0) {
      csds_to_bind$CSDUID <- csds_to_bind$ID
      csds_to_bind$ID <- paste0("CSD_", csds_to_bind$ID)

      census_datasets$CT <- rbind(census_datasets$CT, csds_to_bind)
    }

    # Update CTUID for the rest of the levels
    change_CTUID_for <-
      census_datasets[{
        which(names(census_datasets) == "CT") + 1
      }:length(census_datasets)]

    updated_rest_levels <-
      lapply(change_CTUID_for, \(x) {
        x <- sf::st_transform(x, crs)
        cts <- sf::st_transform(census_datasets$CT, crs)
        x_centroids <- suppressWarnings(sf::st_point_on_surface(x)[, "ID"])

        CSDUID_key <-
          sf::st_drop_geometry(sf::st_join(x_centroids, cts[, "ID"]))
        names(CSDUID_key) <- c("ID", "CTUID")


        x <- merge(x[, names(x) != "CTUID"], CSDUID_key, by = "ID")
        x <- x[, c("ID", "name", "CSDUID", "CTUID", names(x)[
          !names(x) %in% c("ID", "name", "CSDUID", "CTUID")
        ])]

        sf::st_transform(x, 4326)
      })

    census_datasets <-
      c(
        census_datasets[!names(census_datasets) %in% names(change_CTUID_for)],
        updated_rest_levels
      )
  }

  # Add name_2
  census_datasets <-
    mapply(\(df, df_name) {
      if (df_name %in% names(override_name_2)) {
        df$name_2 <- override_name_2[[df_name]]
      } else {
        csds <- sf::st_drop_geometry(census_datasets$CSD[, c("ID", "name")])
        names(csds) <- c("CSDUID", "name_2")
        df$name <- df$ID
        df <- merge(df, csds, by = "CSDUID")
      }

      df[, c("ID", "name", "name_2", names(df)[
        !names(df) %in% c("ID", "name", "name_2")
      ])]
    }, census_datasets, names(census_datasets))

  census_datasets
}
