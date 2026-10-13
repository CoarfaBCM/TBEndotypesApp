# TBEndotypesApp

Simple Shiny app for TB endotype prediction using a pretrained random forest model and top 40 genes.

## Input Format

- Upload either a `.csv` file or a `.xlsx` file (the app reads sheet 1 for Excel).
- The first column must contain gene names (rows are genes).
- Remaining columns must be sample expression values (columns are samples).
- All 40 required genes (from `data/RF_Importancedf_AllBalanced_0.4_commonDBV.xlsx`, first column, first 40 rows) must be present in the uploaded file.
- If any required gene is missing, the app returns an error asking you to confirm gene presence and matrix orientation.

## Output

- The app displays a table with:
  - `SampleName`
  - `PredictedClass`
- Downloaded `.xlsx` file contains:
  - Column 1: `SampleName`
  - Column 2: `PredictedClass`
  - Remaining columns: expression values for the 40 model genes

## Run Locally

1. Install required packages in R:

```r
install.packages(c("shiny", "readxl", "openxlsx", "randomForest", "rsconnect"))
```

2. Start the app from the project directory:

```r
shiny::runApp()
```

## Deploy to shinyapps.io

1. Set up your shinyapps.io account credentials (from Account > Tokens):

```r
rsconnect::setAccountInfo(
  name = "YOUR_ACCOUNT_NAME",
  token = "YOUR_TOKEN",
  secret = "YOUR_SECRET"
)
```

2. Deploy the app:

```r
rsconnect::deployApp(
  appDir = ".",
  appName = "tb-endotypes-app",
  appFiles = c("app.R", "data")
)
```

3. Check logs if deployment or startup fails:

```r
rsconnect::showLogs(appName = "tb-endotypes-app", streaming = TRUE)
```
