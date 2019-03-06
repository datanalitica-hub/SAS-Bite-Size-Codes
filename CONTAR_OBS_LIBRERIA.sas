/****************************************************************************************************************/
/* La siguiente macro sirve para crear una tabla donde se muestren todas las tablas de una misma librer�a junto */
/* con el total de observaciones de cada una.																	*/
/* La ventaja de usar �sta macro sobre querys a DICTIONARY es que DICTIONARY solo funcionar� con librer�as de   */
/* SAS, mientras que con la macro podr� determinar la cantidad de observaciones de cualquier fuente.			*/
/*																			Desarrollada por Fernando Gonz�lez	*/
/****************************************************************************************************************/

%macro CONTEO (_libName);
	%let _qtyTabla=;
	%let i=1;
	
	/*Se crea la tabla libContent para almacenar el resultado del Proc Contents, de aqu� sacaremos 
	  los nombres de las tablas almacenadas en la librer�a objetivo*/
	proc contents data=&_libName.._all_ out=WORK.libContent noprint; run;

	/*Se almacenan en las macros variables _tabla*N* y qtyTabla los nombres de las tablas y la cantidad de �stas 
	  en la librer�a, respectivamente*/
	PROC SQL NOPRINT;
		SELECT DISTINCT MEMNAME, count(DISTINCT memname) INTO :_tabla1 -, :_qtyTabla FROM WORK.LIBCONTENT;
	QUIT;
	/*Al determinar INTO :_Tabla1 - se crean tantas macro variables como cantidad de valores, por ejemplo, si
	  existen 300 tablas en dicha librer�a existiran las macro variables desde _Tabla1 a _Tabla300*/
	
	/*Se crea la tabla CONTEO, que almacenar� el resultado final*/
	DATA CONTEO; STOP; LENGTH TABLA $32 OBS 8; RUN;	
	
	/*Se realiza un ciclo tantas veces como cantidad de variables a evaluar*/
	%DO %WHILE(&i < %eval(&_qtyTabla+1));
		
		/*Se realiza un query para obtener la cantidad de observaciones por tabla*/
		PROC SQL NOPRINT;
			SELECT COUNT(*) INTO :_qtyObs FROM &_libname..&&_tabla&i;
		QUIT;
		
		/*Se crea una tabla dummy que almacenar� la informaci�n de la tabla en analisis durante el ciclo*/
		DATA X;
			LENGTH TABLA $32 OBS 8;
			TABLA = "&&_tabla&i";
			OBS = &_qtyObs;
		RUN;
	
		/*Se realiza un append de la tabla dummy a CONTEO para guardar la informaci�n de la tabla analizada.*/
		PROC APPEND BASE=CONTEO DATA=X; RUN;
		
		/*Se borra la macro variable utilizada para no sobrecargar el enviroment*/
		%symdel &_tabla&i;
		/*Y se incremente i por 1 para continuar con el proceso*/
		%let i = %eval(&i+1);
	%END;
%mend; 

/*Al ejecuatar la macro se solicita el nombre de la librer�a a estudiar*/
*%CONTEO(sashelp);
