### __id__ PAGE

# GLOBAL ------------------------------------------------------------------

`__id___default_region` <- unlist(modules$regions[modules$id == "__id__"])[1]
`__id___mzp` <-
  eval(parse(text = paste0("map_zoom_levels_", `__id___default_region`)))


# UI ----------------------------------------------------------------------

`__id___UI` <- function(id) {
  id_map <- paste0(id, "-map")

  tagList(
    # Sidebar
    sidebar_UI(
      NS(id, id),
      susSidebarWidgets(),
      bottom = div(class = "bottom_sidebar",
                   tagList(legend_UI(NS(id, id)),
                           zoom_UI(NS(id, id), `__id___mzp`)))),

    # Map
    div(class = "mapdeck_div", rdeckOutput(NS(id, id_map), height = "100%")),

    # Right panel
    right_panel(
      id = id,
      compare_UI(NS(id, id), make_dropdown(compare = TRUE)),
      explore_UI(NS(id, id)),
      dyk_UI(NS(id, id)))

  )
}


# Server ------------------------------------------------------------------

`__id___server` <- function(id, r) {
  moduleServer(id, function(input, output, session) {
    id_map <- paste0(id, "-map")

    # Initial reactives
    zoom_string <- reactiveVal(get_zoom_string(map_zoom, `__id___mzp`))
    poi <- reactiveVal(NULL)

    # Map
    output[[id_map]] <- renderRdeck({
      rdeck(map_style = map_base_style, initial_view_state = view_state(
        center = map_loc, zoom = isolate(r[[id]]$zoom())))
    })

    # Zoom and POI reactives
    observe({
      r[[id]]$zoom(get_zoom(get_view_state(id_map)$zoom))
      new_poi <- observe_map(get_view_state(id_map))
      if ((is.null(new_poi) && !is.null(poi())) ||
          (!is.null(new_poi) && (is.null(poi()) || !all(new_poi == poi()))))
        poi(new_poi)
    }) |> bindEvent(get_view_state(id_map))

    # Map zoom levels change depending on r$geo()
    map_zoom_levels <- eventReactive(r$geo(), {
      get_zoom_levels(default = `__id___default_region`,
                      geo = r$geo(),
                      var_left = isolate(var_left()))
    })

    # Zoom string reactive
    observe({
      new_zoom_string <- get_zoom_string(r[[id]]$zoom(), map_zoom_levels()$levels,
                                         map_zoom_levels()$region)
      if (new_zoom_string != zoom_string()) zoom_string(new_zoom_string)
    }) |> bindEvent(r[[id]]$zoom(), map_zoom_levels()$levels)

    # Click reactive
    observe({
      selection <- get_clicked_object(id_map)$ID
      if (!is.na(r[[id]]$select_id()) &&
          selection == r[[id]]$select_id()) {
        r[[id]]$select_id(NA)
      } else r[[id]]$select_id(selection)
    }) |> bindEvent(get_clicked_object(id_map))

    # Default location
    observe({
      if (is.null(r$default_select_id())) return(NULL)
      new_id <- data()$ID[data()$ID %in%
                            r$default_select_id()[[gsub("_.*", "", r[[id]]$df())]]]
      if (length(new_id) == 0) return(NULL)
      r[[id]]$select_id(new_id)
    }) |> bindEvent(r$default_select_id(), r[[id]]$df())

    # Choose tileset
    tile <- zoom_server(
      id = id,
      r = r,
      zoom_string = zoom_string,
      zoom_levels = map_zoom_levels)

    # Get df for explore/legend/etc
    observe(r[[id]]$df(get_df(tile(), zoom_string()))) |>
      bindEvent(tile(), zoom_string())

    # Time
    time <- reactive(`__time__`)

    # Left variable
    var_left <- reactive(paste(`__var_left__`, time(), sep = "_"))

    # Right variable / compare panel
    var_right <- compare_server(
      id = id,
      r = r,
      var_list = make_dropdown(multi_year = FALSE,
                               only_vars = `__var_right__`,
                               only = NULL,
                               exclude = NULL, compare = TRUE),
      time = time)

    # Sidebar
    sidebar_server(id = id, r = r)

    # Data
    data <- reactive(get_data(
      df = r[[id]]$df(),
      geo = map_zoom_levels()$region,
      var_left = var_left(),
      var_right = var_right()))

    # Data for tile coloring
    data_color <- reactive(get_data_color(
      map_zoom_levels = map_zoom_levels()$levels,
      geo = map_zoom_levels()$region,
      var_left = var_left(),
      var_right = var_right()
    ))

    # Year disclaimer
    year_disclaimer_server(
      id = id,
      r = r,
      data = data,
      var_left = var_left,
      var_right = var_right,
      time = time
    )

    # Legend
    legend <- legend_server(
      id = id,
      r = r,
      var_left = var_left,
      var_right = var_right,
      geo = reactive(map_zoom_levels()$region))

    # Did-you-know panel
    dyk_server(
      id = id,
      r = r,
      var_left = var_left,
      var_right = var_right,
      poi = poi)

    # Update map in response to variable changes or zooming
    rdeck_server(
      id = id,
      r = r,
      map_id = "map",
      tile = tile,
      data_color = data_color,
      zoom_levels = reactive(map_zoom_levels()$levels))

    # Update map labels
    label_server(
      id = id,
      r = r,
      map_id = "map",
      tile = tile)

    # Explore panel
    explore_content <- explore_server(
      id = id,
      r = r,
      data = data,
      geo = reactive(map_zoom_levels()$region),
      var_left = var_left,
      var_right = var_right)

    # Bookmarking
    bookmark_server(
      id = id,
      r = r,
      s_id = r[[id]]$select_id,
      df = r[[id]]$df,
      map_viewstate = reactive(get_view_state(id_map)),
      var_left = var_left,
      var_right = var_right,
      more_args = reactive(c())
    )

    # Data transparency and export
    r[[id]]$export_data <- reactive(data_export(id = id,
                                                data = data(),
                                                var_left = var_left(),
                                                var_right = var_right(),
                                                df = r[[id]]$df()))

  })
}
