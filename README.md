 # COVID-19: Excess mortality in Germany

*Last update: 20 May 2020*

**Abstract:**

This article investigates excess mortality in Germany (Übersterblichkeit) from 2016 to April 2020 and in particular possible excess mortality during the Covid-19 outbreak. 

**1. Introduction**

Excess mortality is a temporary increase of mortality (the number of deaths) compared to a (seasonal) baseline. There is evidence, that Covid-19 has led to a significant increase in the number of deaths in countries such as Portugal, England and Wales, France, the Netherlands, and Italy  (["How deadly is COVID-19? A rigorous analysis of excess mortality and age-dependent fatality rates in
Italy"](https://www.medrxiv.org/content/10.1101/2020.04.15.20067074v3.full.pdf) /  ["Excess mortality during COVID-19 in
five European countries and a critique of mortality data analysis"](https://www.medrxiv.org/content/10.1101/2020.04.15.20067074v3.full.pdf)).

The German Robert-Koch-Institut (RKI) has reported correlation of some excess mortality in Germany with Covid-19 (["Täglicher Lagebericht des RKI zur Coronavirus-Krankheit-2019 (COVID-19) 24.04.2020"](https://www.rki.de/DE/Content/InfAZ/N/Neuartiges_Coronavirus/Situationsberichte/2020-04-24-de.pdf?__blob=publicationFile)). However, there seems to be no rigorous assessment so far. 

I investigate excess mortality in Germany based on a simple statistical model which contols for seasonality and temperature.

**2. Data and Methodology**

Data on the number of deaths in Germany are usually published with some delay by the [German Statistical Office (Destatis)](https://www.destatis.de/EN/Home/_node.html). Data on a broader scale is available through [EUROMOMO](https://www.euromomo.eu/). Because of Covid-19, preliminary data on deaths per day by age group has been published by Destatis in May 2020. I use [the preliminary data published by Destatis](https://www.destatis.de/DE/Themen/Gesellschaft-Umwelt/Bevoelkerung/Sterbefaelle-Lebenserwartung/Tabellen/sonderauswertung-sterbefaelle.html) as well as data on reported Covid-19 deaths published by [RKI](https://www.arcgis.com/home/item.html?id=f10774f1c63e40168479a1feb6c7ca74), to investigate excess mortality in Germany.

- Find the data [here](https://github.com/Bixi81/COVID-19_excess_deaths/blob/master/deaths_germany.csv).
- Find the model (R script) [here](https://github.com/Bixi81/COVID-19_excess_deaths/blob/master/covid19_excess_mortality.R).

I use a generalised additive model (GAM) with splines to estimate the a mortality baseline contingent on the year (reference: 2016), the week of the year (reference: week 25), and the max. temperature in Frankfurt am Main as a proxy for overall weather conditions in Germany. Daily data is used to estimate the mortality baseline. The actual number of deaths per day is contrasted to the mortality baseline - as predicted by the GAM model - in order to plot excess mortality. In the model, there is no differentiation of the pre and post Covid-19 period in order to contrast actual mortality figures against a "no Covid-19" baseline.

In a second step, a simple OLS model is used to get an estimate of excess deaths during Covid-19 (defined 23 March 2020 until 19 April 2020; data is available until 19 April only) by adding an indicator for the resprctive period. Otherwise the same explanatory variables are used as in the GAM, described above. See the [R script](https://github.com/Bixi81/COVID-19_excess_deaths/blob/master/covid19_excess_mortality.R) for details.

The figure below shows the (smoothed) numer of actual deaths since 2016 as well as the predicted numer of deaths (GAM model). There clearly is seasonality of mortality, which tends to be higher during the winter month and during very hot periods in the summer 2018/2019.

![ndeaths](deaths_per_day.jpg)

The number of actual deaths between 23 March and 19 April is plotted for each year in the figure below. The figure indicates that the number of deaths has been relatively high in 2020 - in particular in early April - compared to 2016, 2017, and 2019 but the number of deaths is not statistically different when compared to 2018. The flu season 2017/2018 has been the most severe in 30 years and had led to an [estimated 25000 excess deaths](https://www.aerzteblatt.de/nachrichten/106375/Grippewelle-war-toedlichste-in-30-Jahren).

![ndeaths2](death_per_day2.jpg)

**3. Results**



**4. Conclusion**
