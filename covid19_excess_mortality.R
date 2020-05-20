library(readxl)
library(readr)
library(dplyr)
library(magrittr)
library(lubridate)
library(reshape)
library(ggplot2)
library(gam)
library(lmtest)
library(sandwich)
library(huxtable)
library(Metrics)
library(stringr)

# Analysis of excess deaths during Covid-19 in Germany
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Last updated: 20 May 2020
# Author: Peter Heindl

# Data Destatis (overall deaths per day, Germany)
# https://www.destatis.de/DE/Themen/Gesellschaft-Umwelt/Bevoelkerung/Sterbefaelle-Lebenserwartung/Tabellen/sonderauswertung-sterbefaelle.html

# Data RKI (Covid cases and deaths, Germany)
# https://www.arcgis.com/home/item.html?id=f10774f1c63e40168479a1feb6c7ca74

mypath = "C:/Users/User/Documents/R/corona/"

# Covid startdate
covid_startdate = "2020-03-23"

# Daily data on deaths (Germany), Source: Destatis (overall deaths) / RKI (Covid cases and deaths)
t <- read_csv(paste0(mypath,"out/deaths_germany.csv"))

# Data prep
t$year=as.factor(t$year)
t$month=as.factor(t$month)
t$week=as.factor(t$week)
t$corona = ifelse(t$date>=covid_startdate,1,0)

#############################################
# Regressions

#############################################
# Tune GAM for number of splines in temp_max
smp_size <- floor(0.5 * nrow(t))
slist = list()
nlist = list()
maelist = list()
sv=1
c=1
for (sv in seq(1:10)){
  n=1
  for (n in seq(1:100)){
    tryCatch(
      expr = {
        train_ind <- sample(seq_len(nrow(t)), size = smp_size)
        train <- t[train_ind, ]
        test <- t[-train_ind, ]
        gt = gam(total~relevel(year,ref="2016")+relevel(week,ref=25)+s(temp_max,sv),data=train)
        slist[[c]]<-sv
        nlist[[c]]<-n
        maelist[[c]]<-mae(test$total, predict(gt, newdata=test))
        n=n+1
        c=c+1
      },
      error = function(e){
        # Just do nothing, some gams have a missing factor level and are dropped in this try
        #message('Caught an error!')
        #print(e)
      }
    )
  }
  sv=sv+1
}
tuneres = do.call(rbind, Map(data.frame, n=nlist, s=slist, mae=maelist))
rm(slist,nlist,maelist,n,sv,c,test,train,gt,smp_size)
tuneres = tuneres %>%
  group_by(s) %>%
  summarise_at(vars(-n), funs(mean(., na.rm=TRUE)))
tune_mys = as.numeric(which.min(tuneres$mae))
tune_mae = as.numeric(round(min(tuneres$mae)))
rm(tuneres)

#############################################
# GAM 
# No lag(total) is used since this might lead to overfiting -> "weekly" seasonality focus instead of daily lookback
rg = gam(total~relevel(year,ref="2016")+relevel(week,ref=25)+s(temp_max,6),data=t)
plot(rg, se=T, residuals = F)
gam_mae = round(mae(t$total[-1], predict(rg, newdata=t)[-1]))

# Above +30 °C relevant effects

# Dummies for interaction terms with temp
t$above30 = ifelse(t$temp_max>30, 1, 0)

#############################################
# OLS
r = lm(total~relevel(year,ref="2016")+relevel(week,ref=25)+corona+above30*temp_max,data=t)
summary(r)

#############################################
# Number of days in available data
ndays = as.numeric(round(difftime(max(t$date),covid_startdate,units="days")))+1
# Absolute number of reported Covid deaths in Germany in available data
ndeaths = sum(t$covid_deaths[t$date>=covid_startdate])

#############################################
# Get average Covid-19 deaths 
mean(t$covid_deaths[t$date>=covid_startdate])
median(t$covid_deaths[t$date>=covid_startdate])

# Regression result: confidence band
confint(r, "corona")

# Robust SEs
coeftest(r, vcov = vcovHC(r, type="HC1"))

#############################################
# Get estimated excess death by prediction
t$pred_gam = predict(rg,newdata=t)
t$pred_ols = predict(r,newdata=t)
# Get excess deaths as difference to prediction
t$excess = t$total - t$pred_gam

# Summarise excess death per day results from GAM
nexcess_gam = round(sum(t$excess[t$date>=covid_startdate]) / ndays)

#############################################
# Plots

# Plot total deaths (and predicted deaths)
# Reshape for plotting
tplot = t %>% select(date,total,pred_gam)
colnames(tplot)<-c("date","Total", "Predicted")
molten <- melt(data.frame(tplot), id.vars = c("date"))

ggplot(molten, aes(x = date, y = value, colour = variable)) + 
  geom_smooth(method = "gam", formula = y ~ s(x, k = 60),se = T) + #geom_point() +
  xlab("") + ylab("Deaths per day") +
  ggtitle("Deaths per day (Germany) 2016-2020") +
  labs(color='Type') +
  scale_x_date(date_breaks = "months" , date_labels = "%b-%y") + 
  theme(axis.text.x = element_text(angle = 90, hjust = 1))

ggsave(filename=paste0(mypath, "out/deaths_per_day.jpg"), plot=last_plot(), width = 8, height = 4.94, dpi = 300, units = "in", device='png')

# Excess deaths (from GAM prediction)
ggplot(t, aes(x = date, y = excess)) + 
  geom_point(color="lightsteelblue") +
  geom_smooth(method = "gam", formula = y ~ s(x, k = 60),se = T, color = "gray35", fill = "gray40")  +
  xlab("") + ylab("Excess deaths") +
  ggtitle("Excess deaths in Germany 2016-2020 (all age groups)") +
  labs(color='Type') +
  scale_x_date(date_breaks = "months" , date_labels = "%b-%y") + 
  theme(axis.text.x = element_text(angle = 90, hjust = 1)) +
  geom_hline(yintercept=0) +
  geom_text(aes(as.Date("2017-02-15"),0.26,label = "Flu 2017", vjust = 11),color="grey60")+
  geom_text(aes(as.Date("2018-04-01"),0.26,label = "Flu 2018", vjust = 11),color="grey60")

ggsave(filename=paste0(mypath, "out/excess_deaths.jpg"), plot=last_plot(), width = 8, height = 4.94, dpi = 300, units = "in", device='png')

#############################################
# Regression / plots by age group(s)

# Data are provided without clear age group boundaries by Statistisches Bundesamt!
# Data aggregation
t$a0_60 = t$a0_30+t$a30_50+t$a50_55+t$a55_60
t$a61_80 = t$a60_65+t$a65_70+t$a70_75+t$a75_80
t$a81plus = t$a80_85+t$a85_90+t$a90_95+t$a95

#####################
# 0-60
# GAM
rg0_60 = gam(a0_60~relevel(year,ref="2016")+relevel(week,ref=25)+s(temp_max,6),data=t)
t$excess0_60 = t$a0_60 - predict(rg0_60,newdata = t)
# OLS
r0_60 = lm(a0_60~relevel(year,ref="2016")+relevel(week,ref=25)+corona+above30*temp_max,data=t)
# Robust SEs
coeftest(r0_60, vcov = vcovHC(r, type="HC1"))
# Plot
ggplot(t, aes(x = date, y = excess0_60)) + 
  geom_point(color="lightsteelblue") +
  geom_smooth(method = "gam", formula = y ~ s(x, k = 60),se = T, color = "gray35", fill = "gray40")  +
  xlab("") + ylab("Excess deaths") +
  ggtitle("Excess deaths in Germany 2016-2020 (age group 0-60 years)") +
  labs(color='Type') +
  scale_x_date(date_breaks = "months" , date_labels = "%b-%y") + 
  theme(axis.text.x = element_text(angle = 90, hjust = 1)) +
  geom_hline(yintercept=0) +
  geom_text(aes(as.Date("2017-02-15"),0.26,label = "Flu 2017", vjust = 11),color="grey60")+
  geom_text(aes(as.Date("2018-04-01"),0.26,label = "Flu 2018", vjust = 11),color="grey60")+
  coord_cartesian(ylim = c(-300, 600))

ggsave(filename=paste0(mypath, "out/excess_deaths_0_60.jpg"), plot=last_plot(), width = 8, height = 4.94, dpi = 300, units = "in", device='png')

#####################
# 61-80
# GAM
rg61_80 = gam(a61_80~relevel(year,ref="2016")+relevel(week,ref=25)+s(temp_max,6),data=t)
t$excess61_80 = t$a61_80 - predict(rg61_80,newdata = t)
# OLS
r61_80 = lm(a61_80~relevel(year,ref="2016")+relevel(week,ref=25)+corona+above30*temp_max,data=t)
# Robust SEs
coeftest(r61_80, vcov = vcovHC(r, type="HC1"))
# Plot
ggplot(t, aes(x = date, y = excess61_80)) + 
  geom_point(color="lightsteelblue") +
  geom_smooth(method = "gam", formula = y ~ s(x, k = 60),se = T, color = "gray35", fill = "gray40")  +
  xlab("") + ylab("Excess deaths") +
  ggtitle("Excess deaths in Germany 2016-2020 (age group 60-80 years)") +
  labs(color='Type') +
  scale_x_date(date_breaks = "months" , date_labels = "%b-%y") + 
  theme(axis.text.x = element_text(angle = 90, hjust = 1)) +
  geom_hline(yintercept=0) +
  geom_text(aes(as.Date("2017-02-15"),0.26,label = "Flu 2017", vjust = 11),color="grey60")+
  geom_text(aes(as.Date("2018-04-01"),0.26,label = "Flu 2018", vjust = 11),color="grey60")+
  coord_cartesian(ylim = c(-300, 600))

ggsave(filename=paste0(mypath, "out/excess_deaths_61_80.jpg"), plot=last_plot(), width = 8, height = 4.94, dpi = 300, units = "in", device='png')

#####################
# 81++
# GAM
rg81plus = gam(a81plus~relevel(year,ref="2016")+relevel(week,ref=25)+s(temp_max,6),data=t)
t$excess81plus = t$a81plus - predict(rg81plus,newdata = t)
# OLS
r81plus = lm(a81plus~relevel(year,ref="2016")+relevel(week,ref=25)+corona+above30*temp_max,data=t)
# Robust SEs
coeftest(r81plus, vcov = vcovHC(r, type="HC1"))
# Plot
ggplot(t, aes(x = date, y = excess81plus)) + 
  geom_point(color="lightsteelblue") +
  geom_smooth(method = "gam", formula = y ~ s(x, k = 60),se = T, color = "gray35", fill = "gray40")  +
  xlab("") + ylab("Excess deaths") +
  ggtitle("Excess deaths in Germany 2016-2020 (age group 81+ years)") +
  labs(color='Type') +
  scale_x_date(date_breaks = "months" , date_labels = "%b-%y") + 
  theme(axis.text.x = element_text(angle = 90, hjust = 1)) +
  geom_hline(yintercept=0) +
  geom_text(aes(as.Date("2017-02-15"),0.26,label = "Flu 2017", vjust = 11),color="grey60")+
  geom_text(aes(as.Date("2018-04-01"),0.26,label = "Flu 2018", vjust = 11),color="grey60")+
  coord_cartesian(ylim = c(-300, 600))

ggsave(filename=paste0(mypath, "out/excess_deaths_81plus.jpg"), plot=last_plot(), width = 8, height = 4.94, dpi = 300, units = "in", device='png')

#####################
# Plot seasonal comparison (03-23 to 04-19)
ts=t%>%select(date,total)
ts=ts[(ts$date>="2016-03-23"&ts$date<="2016-04-19" | 
         ts$date>="2017-03-23"&ts$date<="2017-04-19" | 
         ts$date>="2018-03-23"&ts$date<="2018-04-19" | 
         ts$date>="2019-03-23"&ts$date<="2019-04-19" | 
         ts$date>="2020-03-23"&ts$date<="2020-04-19"),]

ts$year=year(ts$date)
ts$time=as.character(ts$date)
ts$time=str_sub(ts$time, 6, nchar(ts$time))
ts$date<-NULL
ts$year = as.factor(ts$year)
#colnames(tplot)<-c("date","Total", "Predicted")
#tsmolten <- melt(data.frame(ts), id.vars = c("year","time"))

library(RColorBrewer)
#library(ggthemes)
ggplot(ts, aes(x = time, y = total, group=year, color=year)) + 
  #geom_point(color="lightsteelblue") +
  geom_smooth()  +
  xlab("") + ylab("Deaths per day") +
  ggtitle("Deaths per day 2016-2020 (Germany)") +
  theme(axis.text.x = element_text(angle = 90, hjust = 1)) +
  geom_hline(yintercept=0) +
  coord_cartesian(ylim = c(2000, 3500)) +
  scale_colour_brewer(palette = "Blues") 

ggsave(filename=paste0(mypath, "out/death_per_day2.jpg"), plot=last_plot(), width = 8, height = 4.94, dpi = 300, units = "in", device='png')

#############################################
# Summary of results

# Regression tables
regs <- huxreg('All'=r,'Age 0-60'=r0_60,'Age 61-80'=r61_80, 'Age 80+'=r81plus)
regs

# Mean of reported Covid-19 deaths since covid_startdate
mean(t$covid_deaths[t$date>=covid_startdate])

# Regression result: confidence band
confint(r, "corona")

# Number of days and total number of deaths since covid_startdate
covid_startdate
ndays
ndeaths

# Summarise excess death per day results from GAM
nexcess_gam 

### END
