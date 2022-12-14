#' Build the regions dictionary
#'
#' @param all_tables <`named list`> Named list of regions and their scales within,
#' ordered in priority.
#' @param geo <`vector of character`> A vector of characters used to identify
#' which large geometry the user is interested in, e.g.
#' \code{c("CMA", "city", "island")}.
#' @param name <`named character vector`> Named with their corresponding geo value.
#' Same length as the vector fed in the `geo` argument. Used to name the geo
#' when the user will want to change which large geometry they are interested in. e.g.
#' \code{c("Metropolitan Area", "City of Montreal", "Island of Montreal")}.
#' @param to_compare <`named character vector`> Named with their corresponding geo value.
#' Same length as the vector fed in the `geo` argument. The same length as
#' the vector fed in the `geo` argument. Used at the end of dynamically generated
#' text, when a particular zone is compared with the whole geography. 'x DA
#' has a higher value than y% of DAs in the Montreal region'.
#' e.g. \code{c("in the Montreal region", "in the City of Montreal",
#' "on the island of Montreal")}
#' @param pickable <`named vector of logical`> Will the user be able to select this
#' scale as a default all over the platform?
#'
#' @return Returns the same vectors fed arranged in a data.frame ordered in
#' priorty.
#' @export
regions_dictionary <- function(all_tables, geo, name, to_compare, pickable) {
  # Error check
  if (is.null(names(name))) {
    stop("`geo`must be a named character vector.")
  }
  if (is.null(names(to_compare))) {
    stop("`to_compare`must be a named character vector.")
  }
  invisible(lapply(c("geo", "name", "to_compare", "pickable"), \(x) {
    if (length(get(x)) != length(all_tables)) {
      stop("length of`", x, "` is not the same as the length of `all_tables`")
    }
  }))

  geo <- geo[order(match(geo, names(all_tables)))]
  name <- name[order(match(names(name), names(all_tables)))]
  to_compare <- to_compare[order(match(names(to_compare), names(all_tables)))]
  pickable <- pickable[order(match(names(pickable), names(all_tables)))]


  tibble::tibble(
    geo = geo,
    priority = seq_len(length(geo)),
    name = name,
    to_compare = to_compare,
    pickable = pickable
  )
}
