library(tidyverse)
library(shiny)
library(sf)
library(leaflet)
library(lubridate)
library(openair)


#counts_1 <- read.csv("data/fact-journey-hourly.csv")

dat_csv <- read.csv("https://opendata.bristol.gov.uk/explore/dataset/fact-journey-hourly/download/?format=csv&timezone=Europe/London&lang=en&use_labels_for_header=true&csv_separator=%3B", sep = ";")

route_dat <- read.csv("https://opendata.bristol.gov.uk/explore/dataset/dim-journey-links/download/?format=csv&timezone=Europe/Berlin&lang=en&use_labels_for_header=true&csv_separator=%3B", sep = ";") %>% 
  mutate(link_id = as.character(Journey.Link.ID))
  
#dat_csv <- read.csv("fact-journey-hourly.csv", sep = ";")

dataset <- dat_csv %>% 
  transmute(date = ymd_hms(gsub("T", " ", Date.Time)),
            linkID = as.character(Journey.Link.ID),
            total_t = Total.Matches,
            avg_speed = Speed) %>%
  mutate(month = month(date),
         year = year(date)) %>% 
  group_by(month, year, linkID) %>% 
  summarise(total_t = sum(total_t),
            avg_speed = mean(avg_speed)) %>% 
  mutate(date = ymd(paste(year, month, "1", sep = "-")))

routez <- readRDS("new_routes.RDS")
routez <- left_join(routez, route_dat, by = "link_id")
namez <- transmute(routez, id = link_id,
                   ID = paste0(link_id, " - ", JourneyStart," - ", JourneyEnd))
routez <- mutate(routez, ID = paste0(link_id, " - ", JourneyStart," - ", JourneyEnd))
routez$length <- round(st_length(routez), 0)
st_geometry(namez) <- NULL
dataset <- left_join(dataset, namez, by = c("linkID" = "id"))
tooday <- today("GMT")
last_m <- tooday %m+% months(-1)
last_m_2019 <- as.POSIXlt(as.Date(last_m))
last_m_2019$year <- last_m_2019$year-1
last_m_2019 <- as.Date(last_m_2019)
last_m <- floor_date(last_m, unit = "month")
last_m_2019 <- floor_date(last_m_2019, unit = "month")
last_month <- filter(dataset, date == last_m)
last_m_2019 <- filter(dataset, date == last_m_2019)
last_m_2019 <- select(last_m_2019, linkID, 'total_2019' =  total_t, 'avg_2019' = avg_speed)
last_month <- left_join(last_month, last_m_2019, by = "linkID")
routez <- left_join(routez, last_month, by = c("link_id" = "linkID"))
routez$total_t <- as.numeric(routez$total_t)
routez$total_2019 <- as.numeric(routez$total_2019)
routez$diff_t <- routez$total_t-routez$total_2019
routez$diff_s <- routez$avg_speed-routez$avg_2019
routez$tripz <- ifelse(routez$diff_t > 0,"HIGHER", "LOWER")
routez$speedz <- ifelse(routez$diff_s > 0,"HIGHER", "LOWER")
last_month$year_month <- paste(months(last_month$date), year(last_month$date))
last_month$year_month <- paste(months(last_month$date), year(last_month$date)) 
last_month <- ungroup(last_month)
last_month <- select(last_month, year_month, avg_speed, total_t, ID)
names(last_month) <- c("Date", "Speed (kph)", "Total Trips", "Route")
dset_avg <- timeAverage(dataset, "month")
dset_sum <- timeAverage(dataset, "month", statistic = "sum")
dset_all <- transmute(dset_avg, date, avg_speed, total_t = dset_sum$total_t)
dset_all$year_month <- paste(months(dset_all$date), year(dset_all$date))
dset_all <- ungroup(dset_all)
dset_all <- select(dset_all, year_month, avg_speed, total_t)
names(dset_all) <- c("Date", "Speed (kph)", "Total Trips")
dataset$year_month <- paste(months(dataset$date), year(dataset$date)) 
ds <- dataset
dataset <- ungroup(dataset)
dataset <- select(dataset, year_month, avg_speed, total_t, ID)
names(dataset) <- c("Date", "Speed (kph)", "Total Trips", "Route")
df <- data.frame(id = "ALL", ID = "ALL")
namez$id <- as.numeric(namez$id)
namez$id <- sprintf("%03d", namez$id)
namez <- arrange(namez, id)
s <- rbind(df, namez)
u <- unique(s$ID)
#routez <- select(routez, link_id, avg_speed, ID, total_t, JourneyStartDirection, JourneyStart, Journey.End.Direction, JourneyEnd, length)

save(routez, dataset, dset_all, last_month, ds, namez, last_m_2019, s, u, file = "inputs.RData")
