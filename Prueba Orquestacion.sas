/*Se definen las rutas*/
%let rutaInsumos = C:\SAS\SASData\PruebasOrquestacion\;
%let rutaHistoricos = C:\SAS\SASData\PruebasOrquestacion\Historicos\;
%let rutaPeriodicos = C:\SAS\SASData\PruebasOrquestacion\Periodicos\;
%let rutaCTLFiles = C:\SAS\SASData\PruebasOrquestacion\CTL\;

/*Macro para cargar tabla de control*/
%macro doCargarTablaControl(tabla, accion);
	/*Si es la primera vez que se ejecuta, y la tabla de control no existe, se crea
	  Para poder hacerle append luego*/
	%if %sysfunc(exist(work.tabla_control)) = 0 %then %do;
		data tabla_control;
			length tabla $32 Accion $32 proceso_dt 8;
			format proceso_dt datetime17.;
		run;
	%end;
	
	/*Se crea el registro que se le hara append a tabla de control con la informacion suministrada*/
	data append_tc;
		length tabla $32 Accion $32 proceso_dt 8;
		
		tabla = "&tabla";
		accion = "&accion";
		proceso_dt = datetime();

		format proceso_dt datetime17.;
	run;
	
	/*Se realiza el append a la tabla de control*/
	proc append base=tabla_control data=append_tc; run;
%mend;

/*Macro para mover insumos a carpeta especificada, luego se puede cambiar por la del servidor*/
%macro doMoverInsumos(archivo, folder);
	options noxwait;
	%let cmd = move &rutaInsumos.&archivo..txt &&ruta&folder..&archivo..txt;
	x &cmd;
	
	/*Se invoca la macro de tabla de control para registrar que se movio el archivo*/
	%doCargarTablaControl(&archivo, To &folder);
%mend;

/*Macro para crear los CTL requeridos*/
%macro doCrearCTL(archivo);
	options noxwait;
	%let cmd = copy NUL &rutaCTLFiles.&archivo..CTL;
	x &cmd;
	
	/*Se invoca la macro de tabla de control para registrar que se creo el archivo*/
	%doCargarTablaControl(&archivo..CTL, Created);
%mend;

/*La macro que verifica y mueve todos los insumos de lugar, ademas de que verifica si es la primera vez que se ejecuta
  el proceso y decide que periodo ejecutar despues si no es asi*/
%macro doVerificarInsumos(periodo);
	%let cargados=;
	%let array_nombres=;
	%let array_qty=;

	/*Se obtienen en una macro variable un array con los nombres de los insumos necesarios y la cantidad de
	  insumos a evaluar. Esto viene de una tabla que es resultado de la importacion de un excel*/
	proc sql noprint;
		select substr(nombre,1,find(nombre, ".")-1), count(nombre) into :array_nombres separated by " ",
								 :array_qty
		from lista_insumos where tipo = 'P';
						 /*^^^^^^^^^^^^^^^^^ Estoy usando solo periodicos por ahora pues no se que hacer con historicos*/
	quit;
	
	/*Es importante saber si el proceso del DI esta ejecutando, para no causar conflictos no mas se genera el STG1.CTL que
	  dispara el scheduling tambien se crea un PROCESANDO.CTL (El cual debe ser borrado al terminar el proceso de DI) este
	  le indica al orquestador si ejecutar o no*/
	%if %sysfunc(fileexist("&rutaCTLFiles.PROCESANDO.CTL")) %then 
		/*Si PROCESANDO.CTL existe, significa que el DI esta ejecutando, por ende el orquestador no se ejecuta y solo deja
	      un mensaje en el log*/
		%put "PROCESO EN EJECUCION, PORFAVOR AGUARDE A QUE CULMINE";

		/*Si no existe el archivo, el orquestador es libre de hacer su trabajo*/
	%else %do;
		/*Primero que todo, se verifica que no se haya ejecutado el proceso antes, esto se logra viendo si la tabla
		  PERIODOS_EJECUTADOS existe*/
		%if %sysfunc(exist(work.periodos_ejecutados)) %then %do;
			/*Si existe, significa que fue ejecutado con anterioridad, por lo que el Orquestador no le hara caso al periodo
			  suministrado al invocarlo, si no que determinara el ultimo periodo ejecutado segun la tabla que lo registra*/
			proc sql noprint;
				select max(periodo) into :periodo from periodos_ejecutados;
			quit;
			
			/*Y se calcula cual seria el periodo mas proximo para ejecutarlo*/
			%if %substr("&periodo", 6, 2) < 12 %then %let periodo=%eval(&periodo+1);
			%else %let periodo= %eval(%substr("&periodo",2,4)+1)01;
		%end;
		%else %do;
			/*Si la tabla PERIODOS_EJECUTADOS no existe, se crea para su posterior relleno*/
			data work.periodos_ejecutados;
				length periodo $6 &array_nombres completado completado_dt 8;
				format completado_dt datetime17.;
			run;
		%end;	
		
		/*Con los array extraidos de la tabla que lista los insumos se genera una observacion que buscara
		  si cada uno de los archivos de insumo indicados existe en el respectivo periodo ejecutado*/
		data validacion_insumos;
			periodo = "&periodo";
			%do i=1 %to &array_qty;
				%scan(%quote(&array_nombres),&i,%str( )) = %sysfunc(fileexist(%quote(&rutaInsumos.%sysfunc(TRANWRD(%quote(%scan(%quote(&array_nombres),&i, %str( ))), %str(AAAAMM), %str(&periodo))).txt)));
			%end;
			/*Se suman todos los flags de si los archivos existen*/
			completado=sum(of _numeric_);

			/*Si la suma es igual a la cantidad de insumos se marca como completado*/
			if completado = &array_qty then do;
				completado_dt = datetime();
				call symput("cargados", 1); /*<- Aca se marca que el proceso tiene todo para completarse*/
			end;
			format completado_dt datetime17.;
		run;
		
		/*Si el proceso puede completarse, entonces se ejecutan las siguientes acciones*/
		%if &cargados = 1 %then %do;
			/*Se invoca la macro doMoverInsumos para mover cada insumo a su respectiva carpeta*/
			%do i=1 %to &array_qty;
				%doMoverInsumos(%sysfunc(TRANWRD(%quote(%scan(%quote(&array_nombres),&i, %str( ))), %str(AAAAMM), %str(&periodo))), Periodicos);
			%end;
			
			/*Se crean los archivos CTL*/
			%doCrearCTL(STG1);
			%doCrearCTL(PROCESANDO);
			
			/*Se realiza el append del periodo evaluado a la tabla de PERIODOS_EJECUTADOS*/
			proc append base=periodos_ejecutados data=validacion_insumos; run;
		%end;
	%end;
%mend;

%doVerificarInsumos(201501);
