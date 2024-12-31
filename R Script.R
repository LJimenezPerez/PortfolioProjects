

library(tidyverse)
library(conflicted)
library(scales)
library(tinytex)

# Set dplyr::filter and dplyr::lag as the default choices
conflict_prefer("filter", "dplyr")
conflict_prefer("lag", "dplyr")

#=====================
# STEP 1: COLLECT DATA
#=====================
# # Upload 2019 Q1 and 2020 Q1 datasets:
q1_2019 <- read_csv("2019-Q1.csv")
q1_2020 <- read_csv("2020-Q1.csv")

#====================================================
# STEP 2: WRANGLE DATA AND COMBINE INTO A SINGLE FILE
#====================================================
# Compare column names each of the files
colnames(q1_2019)
colnames(q1_2020)

# Rename columns to match both files

(q1_2019 <- rename(q1_2019
                   ,ride_id = trip_id
                   ,rideable_type = bikeid
                   ,started_at = start_time
                   ,ended_at = end_time
                   ,start_station_name = from_station_name
                   ,start_station_id = from_station_id
                   ,end_station_name = to_station_name
                   ,end_station_id = to_station_id
                   ,member_casual = usertype
))

# Inspect the dataframes and look for incongruencies

str(q1_2019)
str(q1_2020)

# Convert ride_id and rideable_type to character so that they can stack correctly
q1_2019 <-  mutate(q1_2019, ride_id = as.character(ride_id)
                   ,rideable_type = as.character(rideable_type)) 

# Stack individual quarter's data frames into one big data frame
all_trips <- bind_rows(q1_2019, q1_2020)#, q3_2019)#, q4_2019, q1_2020)

# Remove lat, long, birthyear, and gender fields as this data was dropped beginning in 2020
all_trips <- all_trips %>%  
  select(-c(start_lat, start_lng, end_lat, end_lng, birthyear, gender,  "tripduration"))

#======================================================
# STEP 3: CLEAN UP AND ADD DATA TO PREPARE FOR ANALYSIS
#======================================================

# Inspect the new table that has been created
colnames(all_trips)  #List of column names
nrow(all_trips)  #How many rows are in data frame?
dim(all_trips)  #Dimensions of the data frame?
head(all_trips)
str(all_trips)  #See list of columns and data types.
summary(all_trips)  #Statistical summary of data.

# There are a few problems we will need to fix:
# (1) In the "member_casual" column, there are two names for members ("member" and "Subscriber") and two names for casual riders ("Customer" and "casual"). We will need to consolidate that from four to two labels.
# (2) The data can only be aggregated at the ride-level, which is too granular. We will want to add some additional columns of data -- such as day, month, year -- that provide additional opportunities to aggregate the data.
# (3) We will want to add a calculated field for length of ride since the 2020Q1 data did not have the "tripduration" column. We will add "ride_length" to the entire dataframe for consistency.
# (4) There are some rides where tripduration shows up as negative, including several hundred rides where Divvy took bikes out of circulation for Quality Control reasons. We will want to delete these rides.

# In the "member_casual" column, replace "Subscriber" with "member" and "Customer" with "casual"

table(all_trips$member_casual)

# Reassign to the desired values
all_trips <-  all_trips %>% 
  mutate(member_casual = recode(member_casual
                                ,"Subscriber" = "member"
                                ,"Customer" = "casual"))

# Check to make sure the proper number of observations were reassigned
table(all_trips$member_casual)

# Add columns that list the date, month, day, and year of each ride

all_trips$date <- as.Date(all_trips$started_at)
all_trips$month <- format(as.Date(all_trips$date), "%m")
all_trips$day <- format(as.Date(all_trips$date), "%d")
all_trips$year <- format(as.Date(all_trips$date), "%Y")
all_trips$day_of_week <- format(as.Date(all_trips$date), "%A")

#Format the 'ended_at' column to the correct format

all_trips$ended_at <- format(as.POSIXct(all_trips$ended_at, format = "%d/%m/%Y %H:%M"), "%Y-%m-%d %H:%M:%S")
all_trips$started_at <- format(as.POSIXct(all_trips$started_at, format = "%d/%m/%Y %H:%M"), "%Y-%m-%d %H:%M:%S")

# Add a "ride_length" calculation to all_trips (in seconds)

all_trips$ride_length <- difftime(all_trips$ended_at,all_trips$started_at)

# Inspect the structure of the columns
str(all_trips)

# Convert "ride_length" from Factor to numeric so we can run calculations on the data
is.factor(all_trips$ride_length)
all_trips$ride_length <- as.numeric(as.character(all_trips$ride_length))
is.numeric(all_trips$ride_length)

# Remove "bad" data
# The dataframe includes a few hundred entries when bikes were taken out of docks and checked for quality by Divvy or ride_length was negative

all_trips_v2 <- all_trips[!(all_trips$start_station_name == "HQ QR" | all_trips$ride_length<0),]
View(all_trips_v2)
#=====================================
# STEP 4: CONDUCT DESCRIPTIVE ANALYSIS
#=====================================

# Descriptive analysis on ride_length (all figures in seconds)

summary(all_trips_v2$ride_length)

# Compare members and casual users
aggregate(all_trips_v2$ride_length ~ all_trips_v2$member_casual, FUN = mean)
aggregate(all_trips_v2$ride_length ~ all_trips_v2$member_casual, FUN = median)
aggregate(all_trips_v2$ride_length ~ all_trips_v2$member_casual, FUN = max)
aggregate(all_trips_v2$ride_length ~ all_trips_v2$member_casual, FUN = min)

# See the average ride time by each day for members vs casual users
aggregate(all_trips_v2$ride_length ~ all_trips_v2$member_casual + all_trips_v2$day_of_week, FUN = mean)

# Order by Day of the Week
all_trips_v2$day_of_week <- ordered(all_trips_v2$day_of_week, levels=c("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"))

# Now, let's run the average ride time by each day for members vs casual users
aggregate(all_trips_v2$ride_length ~ all_trips_v2$member_casual + all_trips_v2$day_of_week, FUN = mean)

# Replace member to annual riders

all_trips_v2 <- all_trips_v2 %>%
  mutate(member_casual = case_when(
    member_casual == "member" ~ "Annual", 
    member_casual == "casual" ~ "Casual",
    member_casual == "Customer" ~ "Casual",
    member_casual == "Subscriber" ~ "Annual",
    member_casual == "annual" ~ "Annual",
    TRUE ~ member_casual
  ))

# analyze ridership data by type and weekday
all_trips_v2 %>% 
  mutate(weekday = wday(started_at, label = TRUE)) %>%  #creates weekday field using wday()
  group_by(member_casual, weekday) %>%  #groups by usertype and weekday
  summarise(number_of_rides = n()				#calculates the number of rides and average duration 
            ,average_duration = mean(ride_length)) %>% 		# calculates the average duration
  arrange(member_casual, weekday)							

# Visualize the number of rides by rider type
avg_rides_dow <- all_trips_v2 %>%
  filter(!is.na(member_casual)) %>%  # Exclude rows where member_casual is NA
  mutate(weekday = wday(started_at, label = TRUE)) %>% 
  group_by(member_casual, weekday) %>% 
  summarise(
    number_of_rides = n(),
    average_duration = mean(ride_length)
  ) %>% 
  arrange(member_casual, weekday) %>% 
  ggplot(aes(x = weekday, y = number_of_rides, fill = member_casual)) +
  geom_col(position = "dodge") +
  guides(fill = guide_legend(title = "Member Type")) +
  labs(title = "Average Rides by Member", x="Day of Week", y="Number of Rides") +
  scale_y_continuous(labels = label_comma()) +
  scale_fill_manual(values = c("Annual" = "skyblue", "Casual" = "sienna"))
  


# Visualize average duration

avg_duration_dow <- all_trips_v2 %>% 
  filter(!is.na(day_of_week)) %>%  # Exclude rows where day_of_week is NA
  mutate(weekday = wday(started_at, label = TRUE)) %>% 
  group_by(member_casual, weekday) %>% 
  summarise(
    number_of_rides = n(),
    average_duration = mean(ride_length)
  ) %>% 
  arrange(member_casual, weekday) %>% 
  ggplot(aes(x = weekday, y = average_duration, fill = member_casual)) +
  geom_col(position = "dodge") +
  labs(title = "Average Duration by Day of Week", x = "Day of Week", y = "Average Duration (m)") +
  scale_y_continuous(labels = function(x) sprintf("%02d:%02d", floor(x / 3600), floor((x %% 3600) / 60))) +  # Format y-axis as HH:MM
  guides(fill = guide_legend(title = "Member Type")) +
  scale_fill_manual(values = c("Annual" = "skyblue", "Casual" = "sienna"))

#Summary of table

summary(all_trips_v2$ride_length)
aggregate(all_trips_v2$ride_length ~ all_trips_v2$member_casual, FUN = mean)

# Calculate the mean of ride_length and convert it to hh:mm:ss format
mean_ride_length <- aggregate(ride_length ~ member_casual, data = all_trips_v2, FUN = mean)

# Convert the mean ride length (in seconds) to hh:mm:ss format
mean_ride_length$Ride_Lenght_Average <- format(as.POSIXct(mean_ride_length$ride_length, origin = "1970-01-01", tz = "UTC"), "%H:%M:%S")

# Rename 'member_casual' to 'Rider_Type'
colnames(mean_ride_length)[colnames(mean_ride_length) == "member_casual"] <- "Member_Type"

# Select only 'Rider_Type' and 'formatted_time' columns to display
mean_ride_length <- mean_ride_length[, c("Member_Type", "Ride_Lenght_Average")]

print(mean_ride_length)



