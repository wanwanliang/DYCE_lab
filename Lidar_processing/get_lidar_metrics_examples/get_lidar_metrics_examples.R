## set to your working dir, the example data used in this folder is here: https://drive.google.com/drive/folders/1HFLB2nqdxdJIBYdq6DizsaYa3-rc7gDo?usp=drive_link
setwd('C:/Users/liang/OneDrive/Desktop/ABoVE/Lidar/NS/')
source('Lidar_point_cloud_process_functions.R')


########## Example 1:  extracting LiDAR metrics for ground plots #############

aois = st_read('Ground_plots.shp')
aois = st_buffer(aois, dist= 11)  # ground plots are about 11-meter circle 
aois$ID

las_catalog = readLAScatalog('.')
plot(las_catalog)
plot(st_buffer(aois, dist=500), add=T)


### define function to extract lidar metrics for each aoi 
i  = 1
get_ld_metricAll_aoi = function(i, reproj=FALSE){
  aoi = aois[i,]
  if (reproj){
    aoi = st_transform(aoi, st_crs(las_catalog))
  }
  
  ## clip las_catalog by a aoi with bigger buffer to ensure reliable estimation on DTM and DSM
  las = clip_roi(las_catalog, st_buffer(aoi,150))

  ## normalize las file (a function in Lidar_point_cloud_process_functions.R)
  las = normalize_las(las) 
  ## now clip las by the ground plot itself
  las = clip_roi(las, aoi)
  
  #plot(las)  #the visulizaiton is quite pretty
  
  ## get lidar metrics for this ground plot 
  metrics_out= aba_metrics(las, aoi$ID)
  
  
  return(metrics_out)
}


## use loop if there are not a lot of AOIs

for (i in c(1:dim(aois)[1])){
  
  metrics = get_ld_metricAll_aoi(i, reproj=T)
  
  if (i ==1){
    metrics_dfA = metrics
  } else {
    metrics_dfA = rbind(metrics_dfA, metrics)
  }
  
}

head(metrics_dfA)  ## notice the column Year, Day_Year, and Density are not lidar metrics, they are more like meta data of the lidar data


########## Example 2:  Deriving lidar metrics as raster #############

## here rasterize all the lidar tiles using catalog_map on catalogs, the rasterized metrics have the same metrics and same order as shown in above example except Year, Day_Year, and Density are not in the output 
las_catalog = readLAScatalog('.', pattern='346*')
plot(las_catalog)

## create buffer to each chunk in the las_catalog to avoid edge effects
opt_chunk_buffer(las_catalog) <- 30
plot(las_catalog, chunk = TRUE)

## merge all the output rasters, disabled
## options = list(automerge = TRUE) 
## set directory for the output
output_directory <- "C:/Users/liang/OneDrive/Desktop/ABoVE/Lidar/NS/output/"

## set name format for the output rasterized metrics, no need to set the extension (i.e. .tif)
opt_output_files(las_catalog) <- paste0(output_directory,'Metrics_',"{ORIGINALFILENAME}")
## continue to run if error occurs from some processes 
opt_stop_early(las_catalog) <- FALSE

## need to use future package to parallel 
library(future)
plan(multisession, workers = 6L)

## map the get_metricsAll_raster function to all chunks, and the output raster has 10-m resolution
out= catalog_map(las_catalog, get_metricsAll_raster,res=10)

