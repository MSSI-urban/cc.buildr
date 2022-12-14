#' Save all buildings dataset in a SQLite
#'
#' @param path <`character`> Path where to save the `.sqlite`. Defaults to
#' `data/building.sqlite`
#' @param all_scales <`named list`> A named list of sf data.frame
#' containing all scales listed with their regions, normally
#' `scales_variables_modules$scales`.
#'
#' @return Returns an error or nothing if ran successfully. All existing `building`
#' data.frame in the fed `all_scales` are saved in the created `.sqlite`.
#' @export
save_buildings_sqlite <- function(path = "data/building.sqlite", all_scales) {
  # Save all buildings in the same database
  building_path <- "data/building.sqlite"
  if (file.exists(building_path)) unlink(building_path)
  building_sql <- DBI::dbConnect(RSQLite::SQLite(), building_path)

  # Iterate and save every building dataset
  map_over_scales(
    all_scales = all_scales,
    fun = \(geo = geo, scales = scales, scale_name = scale_name,
      scale_df = scale_df) {
      if (scale_name != "building") {
        return()
      }
      geo_scale <- paste0(geo, "_building")
      df <- sf::st_drop_geometry(scale_df)[, c("ID", "name", "name_2", "DA_ID")]

      if (geo_scale %in% DBI::dbListTables(building_sql)) {
        DBI::dbRemoveTable(building_sql, geo_scale)
      }

      DBI::dbWriteTable(building_sql, "pre_pk_building", df)
      DBI::dbExecute(building_sql, paste0(
        "CREATE TABLE ", geo_scale,
        " (ID VARCHAR, ",
        "name VARCHAR, ",
        "name_2 VARCHAR, ",
        "DA_ID VARCHAR,
                     CONSTRAINT building_pk PRIMARY KEY (ID))"
      ))

      DBI::dbExecute(
        building_sql,
        paste0(
          "INSERT INTO ", geo_scale,
          " SELECT * FROM pre_pk_building"
        )
      )
      DBI::dbExecute(building_sql, "DROP TABLE pre_pk_building")
    }
  )

  DBI::dbDisconnect(building_sql)

  # Return nothing
  return(invisible(NULL))
}

#' Save all streets dataset in a SQLite
#'
#' @param path <`character`> Path where to save the `.sqlite`. Defaults to
#' `data/streets.sqlite`
#' @param all_scales <`named list`> A named list of sf data.frame
#' containing all scales listed with their regions, normally
#' `scales_variables_modules$scales`.
#'
#' @return Returns an error or nothing if ran successfully. All existing `streets`
#' data.frame in the fed `all_scales` are saved in the created `.sqlite`.
#' @export
save_streets_sqlite <- function(path = "data/streets.sqlite", all_scales) {
  # Save all buildings in the same database
  streets_path <- "data/streets.sqlite"
  if (file.exists(streets_path)) unlink(streets_path)
  streets_sql <- DBI::dbConnect(RSQLite::SQLite(), streets_path)

  # Iterate and save every streets dataset
  map_over_scales(
    all_scales = all_scales,
    fun = \(geo = geo, scales = scales, scale_name = scale_name,
      scale_df = scale_df) {
      if (scale_name != "streets") {
        return()
      }
      geo_scale <- paste0(geo, "_streets")
      df <- sf::st_drop_geometry(scale_df)[, c("ID", "name", "name_2", "DA_ID")]

      if (geo_scale %in% DBI::dbListTables(streets_sql)) {
        DBI::dbRemoveTable(streets_sql, geo_scale)
      }

      DBI::dbWriteTable(streets_sql, "pre_pk_streets", df)
      DBI::dbExecute(streets_sql, paste0(
        "CREATE TABLE ", geo_scale,
        " (ID VARCHAR, ",
        "name VARCHAR, ",
        "name_2 VARCHAR, ",
        "DA_ID VARCHAR,
                     CONSTRAINT streets_pk PRIMARY KEY (ID))"
      ))

      DBI::dbExecute(
        streets_sql,
        paste0(
          "INSERT INTO ", geo_scale,
          " SELECT * FROM pre_pk_streets"
        )
      )
      DBI::dbExecute(streets_sql, "DROP TABLE pre_pk_streets")
    }
  )

  DBI::dbDisconnect(streets_sql)

  # Return nothing
  return(invisible(NULL))
}

#' Save every scales in their own SQLite database
#'
#' @param data_folder <`character`> Where the `.sqlite` databases should be
#' written to. Defaults to `data/`.
#' @param all_scales <`named list`> A named list of sf data.frame
#' containing all scales listed with their regions, normally
#' `scales_variables_modules$scales`.
#' @param variables <`data.frame`> The `variables` data.frame, normally
#' `scales_variables_modules$variables`.
#' @param scales_to_drop <`character vector`> Scales that shouldn't have their
#' own SQLite database. Defaults to `c("building", "street")`.
#'
#' @return Returns an error or nothing if ran successfully. Every existing region-geo
#' combination is a new SQLite db, and every variable is a table saved in each
#' of the db.
#' @export
save_all_scales_sqlite <- function(data_folder = "data/", all_scales, variables,
                                   scales_to_drop = c("building", "street")) {
  # Drop geometry of other scales
  all_scales_no_geo <-
    map_over_scales(
      all_scales = all_scales,
      fun = \(geo = geo, scales = scales, scale_name = scale_name,
        scale_df = scale_df) {
        if (scale_name %in% scales_to_drop) {
          return()
        }
        sf::st_drop_geometry(scale_df)
      }
    )
  all_scales_no_geo <- lapply(all_scales_no_geo, \(x) x[!sapply(x, is.null)])


  # For all scales, list the tables that will be saved
  sql_table_list <-
    map_over_scales(
      all_scales = all_scales_no_geo,
      fun = \(geo = geo, scales = scales, scale_name = scale_name,
        scale_df = scale_df) {
        var_combinations <-
          lapply(variables$var_code, \(y) {
            vars <- names(scale_df)[grepl(y, names(scale_df))]
            vars <- stringr::str_subset(vars, "_q5|_q3", negate = TRUE)

            sapply(vars, \(x) {
              time_format <- "\\d{4}$"
              q3 <- paste0(
                gsub(time_format, "", x),
                if (grepl(time_format, x)) "q3_" else "_q3",
                stats::na.omit(stringr::str_extract(x, time_format))
              )
              q5 <- paste0(
                gsub(time_format, "", x),
                if (grepl(time_format, x)) "q5_" else "_q5",
                stats::na.omit(stringr::str_extract(x, time_format))
              )

              c(x, q3, q5)
            }, simplify = FALSE, USE.NAMES = TRUE)
          })
        var_combinations <- Reduce(c, var_combinations)

        lapply(var_combinations, \(x) scale_df[, c("ID", x)])
      }
    )

  # Save the scales in the database
  map_over_scales(
    all_scales = all_scales_no_geo,
    fun = \(geo = geo, scales = scales, scale_name = scale_name,
      scale_df = scale_df) {
      geo_scale <- paste(geo, scale_name, sep = "_")

      geo_scale_table_list <- sql_table_list[[geo]][[scale_name]]

      sqlite_path <- paste0(data_folder, geo_scale, ".sqlite")

      db <- DBI::dbConnect(RSQLite::SQLite(), sqlite_path)
      mapply(
        \(df, y)
        DBI::dbWriteTable(db, y, df, overwrite = TRUE),
        geo_scale_table_list, names(geo_scale_table_list)
      )
      DBI::dbDisconnect(db)
    }
  )

  # Add centroid
  map_over_scales(
    all_scales = all_scales_no_geo,
    fun = \(geo = geo, scales = scales, scale_name = scale_name,
      scale_df = scale_df) {
      geo_scale <- paste(geo, scale_name, sep = "_")
      with_geo <- all_scales[[geo]][[scale_name]][, "ID"]

      centroids <- lapply(with_geo$geometry, sf::st_centroid)
      lat <- sapply(centroids, `[[`, 1)
      lon <- sapply(centroids, `[[`, 2)

      df <- sf::st_drop_geometry(with_geo)

      df$lat <- lat
      df$lon <- lon

      sqlite_path <- paste0(data_folder, geo_scale, ".sqlite")

      db <- DBI::dbConnect(RSQLite::SQLite(), sqlite_path)
      DBI::dbWriteTable(db, "centroid", df, overwrite = TRUE)
      DBI::dbDisconnect(db)
    }
  )

  # Keep strings of all available tables in each db
  tables_in_sql <- map_over_scales(
    all_scales = sql_table_list,
    fun = \(geo = geo, scales = scales, scale_name = scale_name,
      scale_df = scale_df) {
      names(scale_df)
    }
  )
  tables_in_sql <- unlist(tables_in_sql, recursive = FALSE)
  names(tables_in_sql) <- gsub("\\.", "_", names(tables_in_sql))
  qs::qsave(tables_in_sql, file = paste0(data_folder, "tables_in_sql.qs"))

  return(invisible(NULL))
}

#' Save short tables as .qsm (regions regrouped)
#'
#' @param data_folder <`character`> Where the `.qsm` files should be
#' written to. Defaults to `data/`.
#' @param all_scales <`named list`> A named list of sf data.frame
#' containing all scales listed with their regions, normally
#' `scales_variables_modules$scales`.
#' @param scales_to_drop <`character vector`> Scales that shouldn't have their
#' own short table. Defaults to `c("building", "street")`.
#'
#' @return Returns an error or nothing if ran successfully. Every `region` is
#' its own `.qsm` file in which there are all the scales trimed down to only
#' the columns from `ID` to `households` (NO data columns).
#' @export
save_short_tables_qs <- function(data_folder = "data/", all_scales,
                                 scales_to_drop = c("building", "street")) {
  mapply(\(scls, geo) {
    scls <- mapply(\(x, y) {
      if (y %in% scales_to_drop) {
        return()
      }
      d <- sf::st_drop_geometry(x)
      d[, 1:which(names(d) == "households")]
    }, scls, names(scls), SIMPLIFY = FALSE)
    scls <- scls[!sapply(scls, is.null)]
    names(scls) <- paste(geo, names(scls), sep = "_")

    for (i in seq_len(length(scls))) {
      assign(names(scls)[[i]], scls[[i]])
    }

    do.call(qs::qsavem, c(lapply(names(scls), rlang::sym),
      file = paste0(data_folder, geo, ".qsm")
    ))
  }, all_scales, names(all_scales))

  return(invisible(NULL))
}

#' Save, for each scale, a table of ID and geometry used for export
#'
#' @param data_folder <`character`> Where the `.qsm` files should be
#' written to. Defaults to `data/`.
#' @param all_scales <`named list`> A named list of sf data.frame
#' containing all scales listed with their regions, normally
#' `scales_variables_modules$scales`.
#' @param scales_to_drop <`character vector`> Scales that shouldn't have their
#' own geometry export Defaults to `c("building", "street")`.
#'
#' @return Returns an error or nothing if ran succesfully. Every scale is saved
#' in their most minimal version. Only used for when a user wants to do a
#' geometry export.
#' @export
save_geometry_export <- function(data_folder = "data/", all_scales,
                                 scales_to_drop = c("buildings", "streets")) {
  if (!file.exists(paste0(data_folder, "geometry_export/"))) {
    dir.create(paste0(data_folder, "geometry_export/"))
  }

  map_over_scales(
    all_scales = all_scales,
    fun = \(geo = geo, scales = scales, scale_name = scale_name,
      scale_df = scale_df) {
      if (scale_name %in% scales_to_drop) {
        return()
      }

      geo_scale <- paste(geo, scale_name, sep = "_")
      out <- scale_df[, "ID"]
      file_link <- paste0(data_folder, "geometry_export/", geo_scale, ".qs")
      qs::qsave(out, file = file_link)
    }
  )

  return(invisible(NULL))
}
