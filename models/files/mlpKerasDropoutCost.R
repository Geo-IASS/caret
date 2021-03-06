modelInfo <- list(label = "Multilayer Perceptron Network with Dropout",
                  library = "keras",
                  loop = NULL,
                  type = "Classification",
                  parameters = data.frame(
                    parameter = c('size', 'dropout', 
                                  "batch_size",
                                  "lr", "rho", "decay", "cost",
                                  "activation"),
                    class = c(rep('numeric', 7), "character"),
                    label = c('#Hidden Units', 'Dropout Rate', 
                              "Batch Size", "Learning Rate",
                              "Rho", "Learning Rate Decay",
                              "Cost", "Activation Function")
                  ),
                  grid = function(x, y, len = NULL, search = "grid") {
                    afuncs <- c("sigmoid", "relu", "tanh")
                    if(search == "grid") {
                      out <- expand.grid(
                        size = ((1:len) * 2) - 1, 
                        dropout = seq(0, .7, length = len), 
                        batch_size = floor(nrow(x)/3),
                        lr = 2e-6,
                        rho = .9,
                        decay = 0,
                        activation = "relu",
                        cost = 1:len
                      )
                    } else {
                      n <- nrow(x)
                      out <- data.frame(
                        size = sample(2:20, replace = TRUE, size = len),
                        dropout = runif(len, max = .7), 
                        batch_size = floor(n*runif(len, min = .1)),
                        lr = runif(len),
                        rho = runif(len),
                        decay = 10^runif(len, min = -5, 0),
                        activation = sample(
                          afuncs, 
                          size = len, 
                          replace = TRUE
                        ),
                        cost = runif(len, min = 1, max = 20)
                      )
                    }
                    out
                  },
                  fit = function(x, y, wts, param, lev, last, classProbs, ...) {
                    require(dplyr)
                    K <- keras::backend()
                    K$clear_session()
                    if(!is.matrix(x)) x <- as.matrix(x)
                    model <- keras::keras_model_sequential()
                    model %>% 
                      keras::layer_dense(
                        units = param$size, 
                        activation = as.character(param$activation), 
                        input_shape = ncol(x)
                      ) %>%
                      keras::layer_dropout(rate = param$dropout,
                                           seed = sample.int(1000, 1))
                    y <- class2ind(y)
                    model %>% 
                      keras::layer_dense(
                        units = length(lev), 
                        activation = 'softmax'
                      ) %>%
                      keras::compile(
                        loss = "categorical_crossentropy",
                        loss_weights = list(param$cost),
                        optimizer = keras::optimizer_rmsprop(
                          lr = param$lr,
                          rho = param$rho,
                          decay = param$decay
                        ),
                        metrics = "accuracy"
                      )
                    model %>% keras::fit(
                      x = x, 
                      y = y,
                      batch_size = param$batch_size,
                      ...
                    )
                    if(last)
                      model <- keras::serialize_model(model)
                    list(object = model)
                  },
                  predict = function(modelFit, newdata, submodels = NULL) {
                    if(inherits(modelFit$object, "raw"))
                      modelFit$object <- keras::unserialize_model(modelFit$object)
                    if(!is.matrix(newdata)) 
                      newdata <- as.matrix(newdata)
                    out <- predict(modelFit$object, newdata)
                    ## check for model type
                    if(ncol(out) == 1) {
                      out <- out[, 1]
                    } else {
                      out <- modelFit$obsLevels[apply(out, 1, which.max)]
                    }
                    out
                  },
                  prob =  function(modelFit, newdata, submodels = NULL) {
                    if(inherits(modelFit$object, "raw"))
                      modelFit$object <- keras::unserialize_model(modelFit$object)
                    if(!is.matrix(newdata)) 
                      newdata <- as.matrix(newdata)
                    out <- predict(modelFit$object, newdata)
                    colnames(out) <- modelFit$obsLevels
                    as.data.frame(out)
                  },
                  varImp = NULL,
                  tags = c("Neural Network", "Cost Sensitive Learning", 
                           "Two Class Only"),
                  sort = function(x) x[order(x$size, -x$dropout),],
                  notes = paste("After `train` completes, the keras model object is serialized",
                                "so that it can be used between R session. When predicting, the", 
                                "code will temporarily unsearalize the object. To make the", 
                                "predictions more efficient, the user might want to use ", 
                                "`keras::unsearlize_model(object$finalModel$object)` in the current", 
                                "R session so that that operation is only done once.",
                                "Also, this model cannot be run in parallel due to",
                                "the nature of how tensorflow does the computations.",
                                "Finally, the cost parameter weights the first",
                                "class in the outcome vector.",
                                
                                "Unlike other packages used by `train`, the `dplyr`",
                                "package is fully loaded when this model is used."),
                  check = function(pkg) {
                    testmod <- try(keras::keras_model_sequential(),
                                   silent = TRUE)
                    if(inherits(testmod, "try-error"))
                      stop("Could not start a sequential model. ",
                           "`tensorflow` might not be installed. ",
                           "See `?install_tensorflow`.", 
                           call. = FALSE)
                    TRUE
                  })
