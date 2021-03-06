# load packages
library(tidyverse)
library(data.table)
library(shiny)
library(shinyWidgets)
library(leaflet)
library(rworldmap)
library(httr)

# COVID DATA ----
parent_url = 'https://raw.githubusercontent.com/CSSEGISandData/COVID-19/master/csse_covid_19_data/csse_covid_19_time_series/'

# urls for csv files
confirmed_url = str_c(parent_url,'time_series_covid19_confirmed_global.csv')
confirmed_us_url = str_c(parent_url,'time_series_covid19_confirmed_US.csv')

deaths_url = str_c(parent_url,'time_series_covid19_deaths_global.csv')
deaths_us_url = str_c(parent_url,'time_series_covid19_deaths_US.csv')

recovered_url = str_c(parent_url,'time_series_covid19_recovered_global.csv')
# recovered data from US not available

#a <- read.csv('data/BCPI_WEEKLY-sd-1972-01-01.csv')

# a <- confirmed_df %>% filter(Country.Region=='US')
# b <- recovered_df %>% filter(Country.Region=='US')
# c <- deaths_df %>% filter(Country.Region=='US')
# 
# check <- full_join(a, b, by=c('Date'))

# fx to convert wide to long format
# wide_to_long <- function(wide_df){
#   long_df <- wide_df %>% 
#     gather(Date, Cases, ends_with('0')) %>%
#     mutate(Date = Date %>%
#              as.Date(format='%m/%d/%y'))
#   return(long_df)
# }

wide_to_long <- function(wide_df){
  long_df <- wide_df %>% 
    gather(Date, Cases, starts_with('x')) %>% 
    mutate(Date = Date %>% 
             str_replace('X', '0') %>%
             str_replace_all('\\.', '-') %>% 
             as.Date(format='%m-%d-%y'))
  return(long_df)
}

confirmed_us_df <- read.csv(confirmed_us_url) %>%
  wide_to_long() %>%
  filter(Cases>0) %>% 
  select(Province.State = Province_State, Country.Region = Country_Region, 
         Lat, Long = Long_, Date, Confirmed = Cases)

deaths_us_df <- read.csv(deaths_us_url) %>%
  wide_to_long() %>%
  filter(Cases>0) %>% 
  select(Province.State = Province_State, Country.Region = Country_Region, 
         Lat, Long = Long_, Date, Deaths = Cases)

confirmed_df <- read.csv(confirmed_url) %>% 
  wide_to_long() %>% 
  rename(Confirmed = Cases) %>%
  filter(Country.Region != 'US', Confirmed>0) %>% 
  rbind(confirmed_us_df) %>% 
  mutate(Confirmed.Sqrt = sqrt(Confirmed))

deaths_df <- read.csv(deaths_url) %>% 
  wide_to_long() %>% 
  rename(Deaths = Cases) %>%
  filter(Country.Region != 'US', Deaths>0) %>% 
  rbind(deaths_us_df) %>%
  mutate(Deaths.Sqrt = sqrt(Deaths))

# recovered data is reported by country
recovered_df <- read.csv(recovered_url) %>% 
  wide_to_long() %>% 
  rename(Recovered = Cases) %>%
  filter(Recovered>0) %>% 
  mutate(Recovered.Sqrt = sqrt(Recovered))
# ----

# STOCKS DATA ----
eco_url = 'http://finmindapi.servebeer.com/api/data'

# Fx to obtain stock time series data
get_stock_data <- function(stock_id){
  payload <- list('dataset' = 'USStockPrice',
                  'stock_id' = stock_id,
                  'date'='2020-01-22')
  response <- POST(eco_url, body = payload, encode = "form")
  print(stock_id)
  data <- response %>% content
  
  df <- do.call('cbind', data$data) %>% 
    data.table %>% 
    unnest(cols = colnames(.))
  
  return(df)
}

# Run if data/stock_data.csv does not exist
# stock_data <- c('^GSPC', '^DJI', '^IXIC') %>% 
#   map(get_stock_data) %>% 
#   bind_rows()
# write_csv(stock_data, 'data/stock_data.csv')

stock_data <- read.csv('data/stock_data.csv', stringsAsFactors = F) %>% 
  mutate(date = as.Date(date))
# ----

# ggplot Aesthetics ----
my_theme <- theme(
  plot.background = element_rect(fill = '#293535', color = '#293535'),
  plot.margin = unit(c(1.5,1.5,1.5,1.5), 'cm'),
  panel.background = element_rect(fill = '#293535'),
  panel.grid.major = element_line(linetype = 'dashed', color = '#4d6a66'),
  panel.grid.minor = element_line(color = '#293535'),
  text = element_text(size = 18, color = '#fffacd'),
  axis.text = element_text(size = 18, color = '#fffacd'),
  axis.title.y = element_text(margin = margin(t=0, r=20, b=0, l=0)),
  legend.background = element_rect(fill = '#4d6a66', color = '#4d6a66')
)
# ----

# COVID_df <- confirmed_df %>% 
#   left_join(deaths_df %>% select(Lat, Long, Date, Deaths, Deaths.Sqrt), 
#             by=c('Lat','Long','Date')) %>% 
#   left_join(recovered_df %>% select(Lat, Long, Date, Recovered, Recovered.Sqrt), 
#             by=c('Lat','Long','Date')) %>% 
#   distinct()
# 
# COVID_df[duplicated(COVID_df %>% select(Lat, Long, Date)),]
# 
# corp_debt_spdf <- read.csv('data/corp_debt.csv') %>% 
#   joinCountryData2Map(joinCode = "ISO3", nameJoinColumn = "LOCATION")

# spatial dataframe of the world
world <- getMap(resolution = 'low')

# https://eric.clst.org/tech/usgeojson/
usa <- rgdal::readOGR('data/USA_20m.json')

# https://thomson.carto.com/tables/canada_provinces/public/map
canada <- rgdal::readOGR('data/canada_provinces.geojson')

# ----

# leaflet() %>% #addTiles() %>%
#   addPolygons(data = world,
#               weight = 1,
#               color = '#293535',
#               fillColor = '#1D2626',
#               fillOpacity = 1) %>% 
#   addPolygons(data = usa,
#               weight = 1,
#               color = '#293535',
#               fillColor = '#4d6a66',
#               fillOpacity = 1)


# new page layout with tabs at the top

ui <- navbarPage(title = "COVID-19 | EFFECTS", theme = "styles.css",
                 

  # first tab of the layout, recorded cases and world map
  tabPanel("Recorded Cases", 
           
    fluidRow(
      column(1),
      column(3,
        tags$div(class = "sidebar-container",
          tags$div(class = "sidebar-title",
            h4("Confirmed Cases")
          ),
          span(h3(textOutput("n_confirmed")), style='color:#d4af37'),
          tags$p(class = "sidebar-percentage", "##%"),
        ),
        tags$div(class = "sidebar-container",
          tags$div(class = "sidebar-title", 
            h4("Recovered") 
          ),
          span(h3(textOutput("n_recovered")), style='color:#79cdcd'),
          tags$p(class = "sidebar-percentage", "##%"),
        ),
        tags$div(class = "sidebar-container", 
          tags$div(class = "sidebar-title", 
            h4("Deaths") 
          ),
          span(h3(textOutput("n_deaths")), style='color:#cd5555'),
          tags$p(class = "sidebar-percentage", "##%"),
        ),
        tags$footer(class = "sidebar-date-container", 
          tags$p(class = "sidebar-date", textOutput("show_date"))
        )
      ),
      column(7,
        tags$div(class = "map-select", 
          selectInput('map_view', label = NULL, choices = c('Worldwide', 'Canada', 'USA'), width = "30%"),
        ),
        conditionalPanel(
          condition = "input.map_view == 'Worldwide'",
          leafletOutput("world_map")
        ), 
        conditionalPanel(
          condition = "input.map_view == 'Canada'",
          leafletOutput("canada_map")
        ),
        conditionalPanel(
          condition = "input.map_view == 'USA'",
          leafletOutput("usa_map")
        ),     
      ),
      column(1)
    ),
    
    # slider input
    fluidRow(
      column(1),
      column(10, 
        tags$div(
            sliderInput("date",
               label = ("Date"),
               min = min(confirmed_df$Date),
               max = max(confirmed_df$Date),
               value = max(confirmed_df$Date),
               animate = animationOptions(interval=600, loop=F),
               timeFormat = "%d %b",
               width = "100%"
             )
         )
      ),
      column(1)
    )
  ),
    
  # second tab of the layout, economy data and chart
  tabPanel("Economy", 
    fluidRow(
      column(1),
      column(3,
        span(h3("DJI"), style='color:#000000'),
        span(h3("GSPC"), style='color:#000000'),
        span(h3("IXIC"), style='color:#000000')
      ),
      column(
        7,plotOutput('coolplot')
      ),
      column(1)
    )
  ),
  
  # third tab of the layout, placeholder for commodities data
  tabPanel("Commodities", 
     fluidRow(
       column(1),
       column(3,
         span(h3("Natural Gas"), style='color:#d4af37'),
         span(h3("Gold"), style='color:#79cdcd'),
         span(h3("Cotton"), style='color:#cd5555')
       ),
       column(
           7, "placeholder"
       )
     )
  )
)
  
  
  
  



# leaflet(options = leafletOptions(minZoom=3, maxZoom=6)) %>% 
#   addPolygons(data = world,
#               weight = 1,
#               color = '#293535',
#               fillColor = '#1D2626',
#               fillOpacity = 1) %>% 
#   addPolygons(data = canada,
#               weight = 1,
#               color = '#293535',
#               fillColor = '#4d6a66',
#               fillOpacity = 1) %>% 
#   setView(lng=-100, lat=60, zoom=3) %>% 
#   setMaxBounds(lng1=-130, lng2=-70, lat1=30, lat2=90) %>% 
#   addCircleMarkers(data = confirmed_df,
#                    ~Long, ~Lat,
#                    radius = ~Confirmed.Sqrt / 10,
#                    weight = 1,
#                    color = '#d4af37',
#                    fillColor = '#d4af37',
#                    fillOpacity = 0.6)

# a <- confirmed_df %>% 
#   filter(Date==max(confirmed_df$Date) & Confirmed>0)
# 
# str_c(format(as.integer(sum(a$Confirmed, na.rm=T)), 
#              big.mark=','), ' Confirmed')
# 
# b <- deaths_df %>% 
#   filter(Date==max(deaths_df$Date) & Deaths>0)
# 
# str_c(format(as.integer(sum(b$Deaths, na.rm=T)), 
#              big.mark=','), ' Confirmed')

server <- function(input, output) {
  r_confirmed <- reactive({
    if (input$map_view == 'Worldwide') {
      confirmed_df %>% 
        filter(Date==input$date)
    } else if (input$map_view == 'Canada') {
      confirmed_df %>% 
        filter(Date==input$date & Country.Region=='Canada')
    } else if (input$map_view == 'USA') {
      confirmed_df %>% 
        filter(Date==input$date & Country.Region=='US')
    }
  })
  
  r_deaths <- reactive({
    if (input$map_view == 'Worldwide') {
      deaths_df %>% 
        filter(Date==input$date)
    } else if (input$map_view == 'Canada') {
      deaths_df %>% 
        filter(Date==input$date & Country.Region=='Canada')
    } else if (input$map_view == 'USA') {
      deaths_df %>% 
        filter(Date==input$date & Country.Region=='US')
    }
  })
  
  r_recovered <- reactive({
    recovered_df %>% 
      filter(Date==input$date)
  })
  
  output$show_date <- renderText({ 
    format(input$date,"%d %B %Y")
  })
  
  output$n_confirmed <- renderText({ 
    str_c(format(as.integer(sum(r_confirmed()$Confirmed, na.rm=T)), 
                 big.mark=','))
  })
  
  output$n_deaths <- renderText({ 
    str_c(format(as.integer(sum(r_deaths()$Deaths, na.rm=T)), 
                 big.mark=','))
  })
  
  output$n_recovered <- renderText({ 
    str_c(format(as.integer(sum(r_recovered()$Recovered, na.rm=T)), 
                 big.mark=','))
  })
  
  output$world_map <- renderLeaflet({
    leaflet(world) %>% 
      addPolygons(weight = 1,
                  color = '#f2f2f2',
                  fillColor = '#cccccc',
                  fillOpacity = 1) %>% 
      setView(lng=10, lat=30, zoom=2)
  })
  
  output$canada_map <- renderLeaflet({
    leaflet(options = leafletOptions(minZoom=3, maxZoom=6)) %>% 
      addPolygons(data = world,
                  weight = 1,
                  color = '#f2f2f2',
                  fillColor = '#1D2626',
                  fillOpacity = 1) %>% 
      addPolygons(data = canada,
                  weight = 1,
                  color = '#f2f2f2',
                  fillColor = '#cccccc',
                  fillOpacity = 1) %>%
      setView(lng=-100, lat=60, zoom=3) %>% 
      setMaxBounds(lng1=-130, lng2=-70, lat1=30, lat2=90)
  })
  
  output$usa_map <- renderLeaflet({
    leaflet(options = leafletOptions(minZoom=3, maxZoom=6)) %>% 
      addPolygons(data = world,
                  weight = 1,
                  color = '#f2f2f2',
                  fillColor = '#1D2626',
                  fillOpacity = 1) %>% 
      addPolygons(data = usa,
                  weight = 1,
                  color = '#f2f2f2',
                  fillColor = '#cccccc',
                  fillOpacity = 1) %>% 
      setView(lng=-170, lat=50, zoom=3) %>% 
      setMaxBounds(lng1=-170, lng2=-40, lat1=10, lat2=70)
  })
  
  update_map <- function(leaflet_map) {
    if (input$map_view == 'Worldwide') {
      leafletProxy(leaflet_map) %>% 
        clearMarkers() %>%
        addCircleMarkers(
          data = r_confirmed(),
          ~Long, ~Lat,
          radius = ~Confirmed.Sqrt / 10,
          weight = 1,
          color = '#d4af37',
          fillColor = '#d4af37',
          fillOpacity = 0.6,
          label = sprintf(
            '<strong>%s</strong>, %s<br/>%s Confirmed<br/>',
            r_confirmed()$Country.Region,
            r_confirmed()$Province.State,
            format(r_confirmed()$Confirmed, big.mark=',')) %>% lapply(htmltools::HTML)
        ) %>%
        addCircleMarkers(
          data = r_recovered(),
          ~Long, ~Lat,
          radius = ~Recovered.Sqrt / 10,
          weight = 1,
          color = '#79cdcd',
          fillColor = '#79cdcd',
          fillOpacity = 0.5
        ) %>% 
        addCircleMarkers(
          data = r_deaths(),
          ~Long, ~Lat,
          radius = ~Deaths.Sqrt / 10,
          weight = 1,
          color = '#cd5555',
          fillColor = '#cd5555',
          fillOpacity = 0.7
        ) 
    } else {
      leafletProxy(leaflet_map) %>% 
        clearMarkers() %>%
        addCircleMarkers(
          data = r_confirmed(),
          ~Long, ~Lat,
          radius = ~Confirmed.Sqrt / 10,
          weight = 1,
          color = '#d4af37',
          fillColor = '#d4af37',
          fillOpacity = 0.6,
          label = sprintf(
            '<strong>%s</strong>, %s<br/>%s Confirmed<br/>',
            r_confirmed()$Country.Region,
            r_confirmed()$Province.State,
            format(r_confirmed()$Confirmed, big.mark=',')) %>% lapply(htmltools::HTML)
        ) %>%
        addCircleMarkers(
          data = r_deaths(),
          ~Long, ~Lat,
          radius = ~Deaths.Sqrt / 10,
          weight = 1,
          color = '#cd5555',
          fillColor = '#cd5555',
          fillOpacity = 0.7
        ) 
    }
  }
  
  observeEvent({
    input$date
    input$map_view
  }, {
    if (input$map_view == 'Worldwide') {
      update_map('world_map')
    } else if (input$map_view == 'Canada') {
      update_map('canada_map')
    } else if (input$map_view == 'USA') {
      update_map('usa_map')
    }
  })
# 
#   observeEvent(input$date, {
#     leafletProxy('world_map') %>% 
#       clearMarkers() %>%
#       addCircleMarkers(
#         data = r_confirmed(),
#         ~Long, ~Lat,
#         radius = ~Confirmed.Sqrt / 10,
#         weight = 1,
#         color = '#d4af37',
#         fillColor = '#d4af37',
#         fillOpacity = 0.6,
#         label = sprintf(
#           '<strong>%s</strong><br/>%d Confirmed<br/>',
#           r_confirmed()$Country.Region, 
#           r_confirmed()$Confirmed) %>% lapply(htmltools::HTML)
#       ) %>%
#       addCircleMarkers(
#         data = r_recovered(),
#         ~Long, ~Lat,
#         radius = ~Recovered.Sqrt / 10,
#         weight = 1,
#         color = '#79cdcd',
#         fillColor = '#79cdcd',
#         fillOpacity = 0.5
#       ) %>% 
#       addCircleMarkers(
#         data = r_deaths(),
#         ~Long, ~Lat,
#         radius = ~Deaths.Sqrt / 10,
#         weight = 1,
#         color = '#cd5555',
#         fillColor = '#cd5555',
#         fillOpacity = 0.7
#       )}, {
#     leafletProxy('canada_map') %>% 
#       clearMarkers() %>%
#       addCircleMarkers(
#         data = r_confirmed(),
#         ~Long, ~Lat,
#         radius = ~Confirmed.Sqrt / 10,
#         weight = 1,
#         color = '#d4af37',
#         fillColor = '#d4af37',
#         fillOpacity = 0.6,
#         label = sprintf(
#           '<strong>%s</strong><br/>%d Confirmed<br/>',
#           r_confirmed()$Country.Region, 
#           r_confirmed()$Confirmed) %>% lapply(htmltools::HTML)
#       ) %>%
#       addCircleMarkers(
#         data = r_recovered(),
#         ~Long, ~Lat,
#         radius = ~Recovered.Sqrt / 10,
#         weight = 1,
#         color = '#79cdcd',
#         fillColor = '#79cdcd',
#         fillOpacity = 0.5
#       ) %>% 
#       addCircleMarkers(
#         data = r_deaths(),
#         ~Long, ~Lat,
#         radius = ~Deaths.Sqrt / 10,
#         weight = 1,
#         color = '#cd5555',
#         fillColor = '#cd5555',
#         fillOpacity = 0.7
#       )
#   })
  
  output$coolplot <- renderPlot({
    ggplot(stock_data, aes(x=date, y=Close, col=stock_id)) +
      geom_line() +
      scale_color_manual(values = c('^GSPC'='gold', '^DJI'='tomato', '^IXIC'='seagreen3')) +
      #scale_y_continuous(breaks=c(10000, 50000)) +
      labs(x=NULL, col=NULL) + 
      my_theme +
      theme(legend.position = 'top')
  })
}

shinyApp(ui, server)
