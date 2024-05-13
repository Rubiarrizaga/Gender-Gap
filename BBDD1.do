clear all
use "C:\Users\Usuario\Desktop\CASEN_y_GG\casen2009stata.dta"

*generar cod de comuna donde reside 
tostring comuna, generate(cod_comuna)
destring cod_comuna, replace

*borrar los que no tienen declarada alguna comuna de trabajo (siempre y cuando declaren no trabajar)
tostring o1, generate(o1bin)
destring t10cod, replace

replace t10cod = cod_comuna if missing(t10cod) & o1bin == "1"

*Asociar a la comuna de residencia lat y long

merge m:1 cod_comuna using comunas_chile.dta

sort _merge

label variable NOM_COM "Comuna de residencia"
rename NOM_COM Comuna_residencia
label variable cod_comuna "codcomuna_reside"
rename p_x_1 lon_reside
rename p_y_1 lat_reside

drop cod_reg nom_reg cod_prov nom_prov _merge

save "C:\Users\Usuario\Desktop\CASEN_y_GG\BBDD1.dta", replace

*Asociar a la comuna donde trabaja lat y long

use "C:\Users\Usuario\Desktop\CASEN_y_GG\comunas_chile.dta"
rename cod_comuna t10cod
merge 1:m t10cod using BBDD1.dta

rename NOM_COM Comuna_trabaja
label variable Comuna_trabaja "Comuna donde trabaja"
rename t10cod CUT_trabaja
label variable CUT_trabaja " CUT donde trabaja"
rename p_x_1 lon_trabaja
rename p_y_1 lat_trabaja

drop if _merge == 2 |  _merge == 1
drop cod_reg nom_reg cod_prov nom_prov _merge

drop if missing(CUT_trabaja) | missing( Comuna_residencia)
replace CUT_trabaja = cod_comuna if CUT_trabaja == 99999

save "C:\Users\Usuario\Desktop\CASEN_y_GG\BBDD1.dta", replace


* agregar superficie (km^2)

use "C:\Users\Usuario\Desktop\CASEN_y_GG\BBDD1.dta", clear // Cargar la primera base de datos
merge m:1 cod_comuna using "C:\Users\Usuario\Desktop\CASEN_y_GG\Superficie_Chile.dta", force
drop if _merge == 2
drop  _merge
save "C:\Users\Usuario\Desktop\CASEN_y_GG\BBDD1.dta", replace

sum CUT_trabaja cod_comuna
*calculo de las distancias para los (lat,lon) 

rename lon_trabaja p_y_1
rename lat_trabaja p_x_1

rename lon_reside p_y
rename lat_reside p_x


************DISTANCIA DE HAVERSINE************
{
* Definir las coordenadas de los puntos (en radianes)
gen lat1_rad = (p_x * _pi) / 180
gen lon1_rad = (p_y * _pi) / 180
gen lat2_rad = (p_x_1 * _pi) / 180
gen lon2_rad = (p_y_1 * _pi) / 180

* Calcular las diferencias de longitud y latitud
gen dlon = lon2_rad - lon1_rad
gen dlat = lat2_rad - lat1_rad

* Aplicar la fórmula del haversine
gen a = sin(dlat/2)^2 + cos(lat1_rad) * cos(lat2_rad) * sin(dlon/2)^2
gen c = 2 * atan(sqrt(a / (1-a)))
gen distancia_km = 6371 * c  // radio de la Tierra en kilómetros

* Puedes convertir la distancia a otras unidades si es necesario
* Por ejemplo, si quieres la distancia en metros, multiplica por 1000
gen distancia_m = distancia_km * 1000
}

rename p_y_1 lon_trabaja 
rename p_x_1 lat_trabaja 

rename p_y lon_reside 
rename p_x lat_reside 

order distancia_km lon_reside lat_reside cod_comuna lat_trabaja lon_trabaja Comuna_trabaja
*browse

***Calcular una distancia nueva para los que tienen distancia = 0

* Calcular la raíz cuadrada de la superficiekm2 / pi
gen nueva_D = cond(distancia_km == 0, sqrt(superficiekm2 / _pi), superficiekm2)

* Reemplazar el cero en la variable superficiekm2
replace distancia_km = nueva_D if distancia_km == 0


*************Genera las variables binarias y categoricas*********
{
tostring e7t, generate(e77tt)
rename e77tt edu
gen cedu = 2
replace cedu = 1 if edu =="1" | edu =="2" | edu =="3" | edu =="4" | edu =="16"
replace cedu = 3 if edu =="10" | edu =="12" | edu =="14" | edu =="15"

tostring sexo, generate(gen)
gen bgen=0
replace bgen = 1 if gen == "2"

tostring zona, generate(bbzon)
gen bzona=0
replace bzona = 1 if bbzon == "1"

tostring ecivil, generate(civil)
gen bcivil=0
replace bcivil = 1 if civil == "1" | civil == "2"

gen ln_wage=ln(yopraj)
gen interaccion=distancia_km*bgen


**************Genrar anillos****************
{
// Generar la variable ring2 basada en la distancia_km
gen ring = ceil(distancia_km / 20)
label variable ring "anillos de 20km"

gen ring50 = ceil(distancia_km / 50)
label variable ring "anillos de 50km"

gen ring100 = ceil(distancia_km / 100)
label variable ring "anillos de 100km"

gen ring120 = ceil(distancia_km / 120)
label variable ring "anillos de 120km"

gen ringB = ceil(distancia_km / 100)
replace ringB = 23 if ringB > 22
label variable ringB "anillos de 100km (agrupados después del anillo 22)"
// Mostrar los valores únicos de la variable ring2
tab ring

}





*************REGRESIONES****************



reg  yoprhaj  cedu o16  bgen#ringB
*   ytrabaj    ytrabhaj bzona  bcivil cedu
outreg2 using reg_table.tex, replace

gen interaccion=bgen*distancia_km
threshold yopraj if distancia_km < 200, threshvar(distancia_km) regionvars(interaccion i.bgen)

threshold yopraj if yopraj < 5000000 & distancia_km < 200, threshvar(distancia_km) regionvars(interaccion i.cedu i.bgen)



*threshold ln_wage, threshvar(interaccion) regionvars(i.cedu i.bgen) nthresholds(12)

threshold ln_wage if yopraj < 5000000 & distancia_km < 200, threshvar(interaccion) regionvars(i.cedu i.bgen) nthresholds(10)

*threshold yopraj if yopraj < 5000000, threshvar(interaccion) regionvars(i.cedu i.bgen) nthresholds(5)
****************


threshold ln_w if distancia_km <15, threshvar(distancia_km) regionvars(cedu i.bgen ) nthresholds(6)


clear all 



*GRAFICAS
scatter ln_wage distancia_km if bgen == 1


replace coeficiente = subinstr(coeficiente, ",", ".", .)
destring coeficiente, replace








use "C:\Users\Usuario\Desktop\CASEN_y_GG\resultados trheshold 13 abril.dta"


// Crear un gráfico de dispersión con puntos y líneas de intervalo de confianza
twoway (scatter coeficiente A, mlabel(A) msymbol(o) msize(small)) ///
    (rcap lowerCI upperCI A)
	
	, ///
    xlabel("A") ylabel("Coeficiente estimado") ///
    title("Coeficiente estimado con intervalo de confianza para cada umbral") ///
    yline(0) ///
    legend(order(1 "Coeficiente estimado" 2 "Intervalo de confianza"))

use resultados

// Crear un gráfico de barras con intervalo de confianza
twoway (bar coeficiente A) (rcap lowerCI upperCI A), ///
    xtitle("Umbral") ytitle("Coeficiente estimado") ///
    title("Coeficiente estimado con intervalo de confianza para cada umbral")

	* puntos unidos con linea
twoway (scatter coeficiente A, mlabel(A) msymbol(o) msize(small)) ///
    (rcap lowerCI upperCI A) ///
    (scatter coeficiente A, connect(l)) ///
    ,  title("Coeficiente estimado con intervalo de confianza para cada A") ///
    yline(0) ///
    legend(order(1 "Coeficiente estimado" 2 "Intervalo de confianza"))


	
	
twoway (scatter coeficiente A, mlabel(coeficiente) msymbol(o) msize(small) mlabpos(12)) ///
    (rcap lowerCI upperCI A) ///
    (scatter coeficiente A, connect(l)) ///
    , title("Wage Gap by Distance for Women") ///
    yline(0) ///
    legend(order(1 "Estimated coefficient" 2 "Confidence interval"))
	


	

