library(shiny)
library(readxl)
library(openxlsx)
library(randomForest)

ui <- fluidPage(
  titlePanel("TB Endotype Classifier"),
  tabsetPanel(
    tabPanel(
      "prediction",
      sidebarLayout(
        sidebarPanel(
          fileInput(
            inputId = "userfile",
            label = "Upload data (.csv or .xlsx)",
            accept = c(".csv", ".xlsx")
          ),
          uiOutput("run_button_ui"),
          br(),
          br(),
          uiOutput("download_ui")
        ),
        mainPanel(
          verbatimTextOutput("status_message"),
          tableOutput("prediction_table")
        )
      )
    ),
    tabPanel(
      "readme",
      tags$pre(
        "here are the 40 genes required for endotype prediction:
TTC27
CD247
NFE2
ZNF529
UBAP1
PINK1
WDR54
NMT2
PPP3CC
RPAIN
SLC22A4
FURIN
DDX18
RTTN
FBXO31
TYSND1
EXOSC10
KLHL3
CMTM5
STAT4
MAP4K1
EVL
GLOD4
PCID2
IMP3
SKAP1
DAP
PDHB
GPR137
ETS1
TREML1
PVRIG
USP14
PARP15
ZNF831
P2RY10
CTNNAL1
RPUSD2
ELP2
PRKCH
"
      )
    )
  )
)

server <- function(input, output, session) {
  topgenes_path <- file.path("data", "RF_Importancedf_AllBalanced_0.4_commonDBV.xlsx")
  model_path <- file.path("data", "RF_Classifier_40genes_AllBalanced_0.4_commonDBV.rds")

  topgenes_source <- readxl::read_xlsx(topgenes_path, sheet = 1, .name_repair = "minimal")
  topgenes <- as.character(topgenes_source[[1]][1:40])

  if (length(topgenes) < 40 || any(is.na(topgenes)) || any(topgenes == "")) {
    stop("Top genes file is invalid: expected at least 40 non-empty values in first column.")
  }

  rf_model <- readRDS(model_path)

  status_message <- reactiveVal("Upload a file and click 'Run Classification'.")
  download_df <- reactiveVal(NULL)

  process_result <- eventReactive(input$run_classification, {
    req(input$userfile)

    ext <- tolower(tools::file_ext(input$userfile$name))
    if (!(ext %in% c("csv", "xlsx"))) {
      stop("Please upload a .csv or .xlsx file.")
    }

    if (ext == "csv") {
      userdf <- read.csv(
        input$userfile$datapath,
        stringsAsFactors = FALSE,
        check.names = FALSE,
        row.names = NULL
      )
    } else {
      userdf <- as.data.frame(
        readxl::read_xlsx(input$userfile$datapath, sheet = 1, .name_repair = "minimal"),
        stringsAsFactors = FALSE,
        check.names = FALSE
      )
    }

    if (ncol(userdf) < 2) {
      stop("Uploaded data must have genes in column 1 and at least one sample column.")
    }

    user_genes <- as.character(userdf[[1]])
    missing_topgenes <- setdiff(topgenes, user_genes)

    if (length(missing_topgenes) > 0) {
      stop(
        paste0(
          "Some topgenes are not found in the data user has uploaded, make sure all topgenes ",
          "are present and the data is in the form of rows of genes and columns of samples.\n",
          "Missing gene(s): ", paste(missing_topgenes, collapse = ", ")
        )
      )
    }

    testdf <- userdf[match(topgenes, user_genes), , drop = FALSE]
    rownames(testdf) <- NULL

    if (nrow(testdf) != 40) {
      stop("Filtered testdf does not have exactly 40 rows.")
    }

    gene_names <- as.character(testdf[[1]])
    expr_matrix <- as.matrix(testdf[, -1, drop = FALSE])
    mode(expr_matrix) <- "numeric"

    model_input <- as.data.frame(t(expr_matrix), stringsAsFactors = FALSE)
    colnames(model_input) <- gene_names

    sample_names <- colnames(testdf)[-1]
    rownames(model_input) <- sample_names

    predicted <- predict(rf_model, newdata = model_input)
    predicted_class <- as.character(predicted)

    export_df <- cbind(
      data.frame(
        SampleName = sample_names,
        PredictedClass = predicted_class,
        stringsAsFactors = FALSE,
        check.names = FALSE
      ),
      model_input
    )
    rownames(export_df) <- NULL

    list(
      download_table = export_df
    )
  })

  observeEvent(input$run_classification, {
    result <- tryCatch(
      process_result(),
      error = function(e) e
    )

    if (inherits(result, "error")) {
      status_message(result$message)
      download_df(NULL)
    } else {
      status_message("Classification complete.")
      download_df(result$download_table)
    }
  })

  output$status_message <- renderText({
    status_message()
  })

  output$prediction_table <- renderTable({
    download_df()
  })

  output$run_button_ui <- renderUI({
    req(input$userfile)
    actionButton("run_classification", "Run Classification")
  })

  output$download_ui <- renderUI({
    req(download_df())
    downloadButton("download_results", "Download Results (XLSX)")
  })

  output$download_results <- downloadHandler(
    filename = function() {
      paste0("classification_results_", format(Sys.time(), "%Y-%m-%d_%H-%M-%S"), ".xlsx")
    },
    content = function(file) {
      req(download_df())
      openxlsx::write.xlsx(download_df(), file, rowNames = FALSE)
    }
  )
}

shinyApp(ui = ui, server = server)

# rsconnect::deployApp(
#   appDir = ".",
#   appName = "tb-endotype-classification",
#   appFiles = c("app.R", "data")
# )
