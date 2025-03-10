###############################################################################
# Extract entries of endpoints containing diy_p1781594777(Carcinoma in situ of breast(*))
# and diy_p1232015483 (CKB0022 - Breast cancer (ICD-10: C50)(*)) and merge them
# for the phenotype file. Note that the date information is also included for
# time-to-event analysis in the near future.
##############################################################################

endpoints <- readRDS("endpoints.rds")

# define the patterns to match
patterns <- c("diy_p1232015483", "diy_p1781594777")

# extract the matching columns
columns_to_extract <- c("csid", grep(paste(patterns, collapse = "|"), colnames(endpoints), value = TRUE))
extracted_data <- endpoints[, columns_to_extract, drop = FALSE]

print(head(extracted_data))
output_file <- "extracted_endpoints.csv"
write.csv(extracted_data, file = output_file, row.names = FALSE)

cat("Extracted data saved to:", output_file, "\n")

###############################################################################
# Extract entries of baseline questionnaires suggested by Christiana
##############################################################################
baseline_questionnaires <- readRDS("data_baseline_questionnaires.rds")
columns_to_extract <- c(
  "csid", "region_code", "region_is_urban", "study_date",
  "study_date_year", "study_date_month", "study_date_day",
  "study_date_hour", "study_date_time", "is_female",
  "dob_anon", "dob_y", "dob_m", "dob_d_anon",
  "age_at_study_date_x100", "cancer_diag", "cancer_site"
)

missing_columns <- setdiff(columns_to_extract, colnames(baseline_questionnaires))
if (length(missing_columns) > 0) {
  stop("The following columns are missing in the dataset: ", paste(missing_columns, collapse = ", "))
}

extracted_data <- baseline_questionnaires[, columns_to_extract, drop = FALSE]
print(head(extracted_data))

# save the extracted data to a CSV file
output_file <- "extracted_baseline_questionnaires.csv"
write.csv(extracted_data, file = output_file, row.names = FALSE)

cat("Extracted data saved to:", output_file, "\n")

#############################################################################
# we still need to check if the `csid` rows are matched
#############################################################################

extracted_baseline_questionnaires <- read.csv("extracted_baseline_questionnaires.csv")
extracted_endpoints <- read.csv("extracted_endpoints.csv")

# check if the `csid` columns exist in both datasets
if (!"csid" %in% colnames(extracted_baseline_questionnaires) || !"csid" %in% colnames(extracted_endpoints)) {
  stop("The `csid` column is missing in one or both datasets.")
}

# check if the number of rows is the same
if (nrow(extracted_baseline_questionnaires) != nrow(extracted_endpoints)) {
  cat("The datasets have different numbers of rows. Cannot compare row by row.\n")
} else {
  # compare `csid` values row by row
  csid_match <- extracted_baseline_questionnaires$csid == extracted_endpoints$csid
  if (all(csid_match, na.rm = TRUE)) {
    cat("All rows in the `csid` columns are matched.\n")
  } else {
    cat("There are mismatches in the `csid` columns.\n")
    # identify and print mismatched rows
    mismatched_rows <- which(!csid_match)
    cat("Mismatched rows:\n")
    print(mismatched_rows)

    mismatched_values <- data.frame(
      baseline_csid = extracted_baseline_questionnaires$csid[mismatched_rows],
      endpoints_csid = extracted_endpoints$csid[mismatched_rows]
    )
    print(mismatched_values)
  }
}

#######################################################################
# replace the csid column in extracted_baseline_questionnaires.csv with its
# corresponding ccvid column from gwas_genetics
#######################################################################
extracted_baseline_questionnaires <- read.csv("extracted_baseline_questionnaires.csv")
gwas_genetics <- readRDS("data_gwas_genetics.rds")

# check if both `csid` and `ccvid` columns exist in gwas_genetics
if (!("csid" %in% colnames(gwas_genetics)) || !("ccvid" %in% colnames(gwas_genetics))) {
  stop("The columns `csid` and/or `ccvid` are missing in gwas_genetics.")
} else {
  cat("Success: Both `csid` and `ccvid` columns are present in gwas_genetics.\n")
}

# merge `ccvid` from gwas_genetics into extracted_baseline_questionnaires using `csid`
merged_data <- merge(
  extracted_baseline_questionnaires,
  gwas_genetics[, c("csid", "ccvid")],  # Keep only csid and ccvid for merging
  by = "csid",  # Merge on the csid column
  all.x = TRUE  # Retain all rows from extracted_baseline_questionnaires
)

# replace `csid` with `ccvid`
merged_data$csid <- merged_data$ccvid
colnames(merged_data)[colnames(merged_data) == "csid"] <- "FID"

merged_data$IID <- merged_data$FID
column_order <- c("FID", "IID", setdiff(colnames(merged_data), c("FID", "IID")))
merged_data <- merged_data[, column_order]

# remove the old `ccvid` column
merged_data$ccvid <- NULL

output_file <- "updated_baseline_questionnaires.csv"
write.csv(merged_data, file = output_file, row.names = FALSE)
cat("Updated baseline_questionnaires saved to:", output_file, "\n")

####################################################################
# run the similar steps for endpoints data
####################################################################

extracted_endpoints <- read.csv("extracted_endpoints.csv")
gwas_genetics <- readRDS("data_gwas_genetics.rds")

if (!("csid" %in% colnames(gwas_genetics)) || !("ccvid" %in% colnames(gwas_genetics))) {
  stop("The columns `csid` and/or `ccvid` are missing in gwas_genetics.")
} else {
  cat("Success: Both `csid` and `ccvid` columns are present in gwas_genetics.\n")
}

merged_data <- merge(
  extracted_endpoints,
  gwas_genetics[, c("csid", "ccvid")],
  by = "csid",
  all.x = TRUE
)

merged_data$csid <- merged_data$ccvid
colnames(merged_data)[colnames(merged_data) == "csid"] <- "FID"

merged_data$IID <- merged_data$FID

column_order <- c("FID", "IID", setdiff(colnames(merged_data), c("FID", "IID")))
merged_data <- merged_data[, column_order]

merged_data$ccvid <- NULL

output_file <- "updated_extracted_endpoints.csv"
write.csv(merged_data, file = output_file, row.names = FALSE)

cat("Updated extracted_endpoints saved to:", output_file, "\n")

####################################################################
# combine updated_baseline_questionnaires.csv and updated_extracted_endpoints.csv
####################################################################

baseline_questionnaires <- read.csv("updated_baseline_questionnaires.csv")
extracted_endpoints <- read.csv("updated_extracted_endpoints.csv")
combined_data <- merge(
  baseline_questionnaires,
  extracted_endpoints,
  by = c("FID", "IID"),
  all = TRUE
)
combined_data <- combined_data[order(match(combined_data$FID, baseline_questionnaires$FID)), ]
output_file <- "combined_baseline_and_endpoints.csv"
write.csv(combined_data, file = output_file, row.names = FALSE)
cat("Combined data saved to:", output_file, "\n")

########################################################################
# filter out the phenotype data for standard GWAS
# we should filter the csv file directly before converting it into txt files
########################################################################

data <- read.csv("combined_baseline_and_endpoints.csv")
filtered_data <- data[data$is_female != 0, ]
output_file <- "women_only_combined_baseline_and_endpoints.csv"
write.csv(filtered_data, file = output_file, row.names = FALSE)
cat("Filtered data saved to:", output_file, "\n")

filtered_data <- read.csv("women_only_combined_baseline_and_endpoints.csv")

columns_to_remove <- c(
  "region_code", "study_date", "study_date_year", "study_date_month", "study_date_day",
  "study_date_hour", "study_date_time", "is_female", "dob_anon", "dob_y", "dob_m",
  "dob_d_anon", "ep_diy_p1232015483_combined_datedeveloped", "ep_diy_p1232015483_da_datedeveloped",
  "ep_diy_p1232015483_dis_datedeveloped", "ep_diy_p1232015483_du_datedeveloped",
  "ep_diy_p1232015483_hiip_datedeveloped", "ep_diy_p1232015483_hiop_datedeveloped",
  "ep_diy_p1232015483_icase_datedeveloped", "ep_diy_p1232015483_oa_datedeveloped",
  "ep_diy_p1232015483_pvd_datedeveloped", "ep_diy_p1781594777_combined_datedeveloped",
  "ep_diy_p1781594777_da_datedeveloped", "ep_diy_p1781594777_dis_datedeveloped",
  "ep_diy_p1781594777_du_datedeveloped", "ep_diy_p1781594777_hiip_datedeveloped",
  "ep_diy_p1781594777_hiop_datedeveloped", "ep_diy_p1781594777_icase_datedeveloped",
  "ep_diy_p1781594777_oa_datedeveloped", "ep_diy_p1781594777_pvd_datedeveloped"
)

filtered_data <- filtered_data[, !(colnames(filtered_data) %in% columns_to_remove)]

output_file <- "filtered_women_only_combined_baseline_and_endpoints.csv"
write.csv(filtered_data, file = output_file, row.names = FALSE)
cat("Final filtered data saved to:", output_file, "\n")

data <- read.csv("filtered_women_only_combined_baseline_and_endpoints.csv")
output_file <- "filtered_women_only_combined_baseline_and_endpoints.txt"
write.table(
  data,
  file = output_file,
  row.names = FALSE,  # Do not include row names
  col.names = TRUE,   # Include column names
  sep = " ",          # Use space as the delimiter
  quote = FALSE       # Do not include quotes around values
)
cat("CSV file converted to space-delimited text file and saved to:", output_file, "\n")


filtered_data <- read.csv("filtered_women_only_combined_baseline_and_endpoints.csv")
non_na_count <- sum(!is.na(filtered_data$cancer_site))
cat("Number of non-NA rows in cancer_site:", non_na_count, "\n")
