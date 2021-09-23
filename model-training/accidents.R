# Trains a simple model to predict the likelihood of fatality given information about a car accident.

# load data
accidents <- readRDS(file.path("accidents.Rd"))

# check dataset
summary(accidents)

# train model
model <-
  glm(
    dead ~ dvcat + seatbelt + frontal + sex + ageOFocc + yearVeh + airbag  + occRole,
    family = binomial,
    data = accidents
  )
summary(model)

# evaluate model quality
predictions <- factor(ifelse(predict(model) > 0.1, "dead", "alive"))
accuracy <- mean(predictions == accidents$dead)

# save model for webservice
saveRDS(model, file = "./webservice/model.rds")
