% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/tilesets.R
\name{tileset_upload_tile_source}
\alias{tileset_upload_tile_source}
\title{Upload a tilesource to a Mapbox account}
\usage{
tileset_upload_tile_source(df, id, username, access_token)
}
\arguments{
\item{df}{<\verb{sf data.frame}> The \code{sf} data.frame that must be uploaded to
mapbox. CRS must be 4326.}

\item{id}{<\code{character}> The ID of the new tile source. For a scale, usually
follows a prefix (mtl), the region (CMA), and the scale (CSD), e.g \code{mtl_CMA_CSD}.}

\item{username}{<\code{character}> Mapbox account username.}

\item{access_token}{<\code{character}> Private access token to the Mapbox account.}
}
\value{
Returns nothing if succeeds.
}
\description{
Upload a tilesource to a Mapbox account
}
