options mprint mlogic;
%let vCantReglas = 0;
%global vScenario_nm vVERSION       vANALYSIS vTIME      vINTORG     vACCOUNT vPRODUCTO 
        vEMPLEADO 	 vGRAN_PROYECTO vCURRENCY vFREQUENCY vINICIO_MES vFIN_MES vDS_RESULTANTE 
  	    vIM_VERSION vIM_ANALYSIS vIM_TIME vIM_INTORG vIM_ACCOUNT vIM_PRODUCTO vIM_EMPLEADO vIM_GRAN_PROYECTO vIM_CURRENCY vIM_FREQUENCY     
        vIL_VERSION vIL_ANALYSIS vIL_TIME vIL_INTORG vIL_ACCOUNT vIL_PRODUCTO vIL_EMPLEADO vIL_GRAN_PROYECTO vIL_CURRENCY vIL_FREQUENCY
        vIR_VERSION vIR_ANALYSIS vIR_TIME vIR_INTORG vIR_ACCOUNT vIR_PRODUCTO vIR_EMPLEADO vIR_GRAN_PROYECTO vIR_CURRENCY vIR_FREQUENCY;
%let varParNames = VERSION ANALYSIS TIME INTORG ACCOUNT PRODUCTO EMPLEADO GRAN_PROYECTO CURRENCY FREQUENCY;
	
%include "C:\Users\datanalitica\Documents\Fernando\Banco del Progreso\reglas_fmquery.sas";


%macro cuentareglas;
	proc sql noprint;
		select max(scenario_id) into :vCantReglas
		from fmquery.reglas_fmquery;
	quit;
%mend;


%macro buscaregla(nRegla);
	proc sql noprint;
		select scenario_nm,   VERSION,  ANALYSIS,  TIME,       INTORG,  ACCOUNT, PRODUCTO, EMPLEADO, 
			   GRAN_PROYECTO, CURRENCY, FREQUENCY, INICIO_MES, FIN_MES,	DS_RESULTANTE, 
    	  	   IM_VERSION, IM_ANALYSIS, IM_TIME, IM_INTORG, IM_ACCOUNT, IM_PRODUCTO, IM_EMPLEADO, IM_GRAN_PROYECTO, IM_CURRENCY, IM_FREQUENCY, 
    	  	   IL_VERSION, IL_ANALYSIS, IL_TIME, IL_INTORG, IL_ACCOUNT, IL_PRODUCTO, IL_EMPLEADO, IL_GRAN_PROYECTO, IL_CURRENCY, IL_FREQUENCY,
    	  	   IR_VERSION, IR_ANALYSIS,	IR_TIME, IR_INTORG, IR_ACCOUNT,	IR_PRODUCTO, IR_EMPLEADO, IR_GRAN_PROYECTO,	IR_CURRENCY, IR_FREQUENCY
		into :vScenario_nm,   :vVERSION,  :vANALYSIS,  :vTIME,       :vINTORG,  :vACCOUNT, :vPRODUCTO, :vEMPLEADO, 
			 :vGRAN_PROYECTO, :vCURRENCY, :vFREQUENCY, :vINICIO_MES, :vFIN_MES,	:vDS_RESULTANTE, 
		  	 :vIM_VERSION,  :vIM_ANALYSIS,      :vIM_TIME,     :vIM_INTORG,        :vIM_ACCOUNT,  :vIM_PRODUCTO, :vIM_EMPLEADO, :vIM_GRAN_PROYECTO, 
		  	 :vIM_CURRENCY, :vIM_FREQUENCY,     :vIL_VERSION,  :vIL_ANALYSIS,      :vIL_TIME,     :vIL_INTORG,   :vIL_ACCOUNT,  :vIL_PRODUCTO, 
		  	 :vIL_EMPLEADO, :vIL_GRAN_PROYECTO, :vIL_CURRENCY, :vIL_FREQUENCY,     :vIR_VERSION,  :vIR_ANALYSIS,	:vIR_TIME,     :vIR_INTORG, 
		  	 :vIR_ACCOUNT,	:vIR_PRODUCTO,      :vIR_EMPLEADO, :vIR_GRAN_PROYECTO, :vIR_CURRENCY, :vIR_FREQUENCY
	    from fmquery.reglas_fmquery
		where scenario_id = &nRegla;
	quit;
%mend;

%macro procesar_fmquery;
	%cuentareglas;
	%put &=vCantReglas;
	%let im = vIM_; %let il = vIL_; %let ir = vIR_; *<-Locura para que mas abajo leyera la macro variable;
	%do nregla = 1 %to 2; *<--------------------Volver a ponr &vCantReglas al terminar pruebas;
		%buscaregla (&nregla);
		%put &=vScenario_nm;
		%do nmes = &vINICIO_MES %to &vFIN_MES;
		    %let v_periodo = %sysfunc(cats(&Periodo,.,%sysfunc(putn(&nmes,mesn.))));
			data work.queryparameters;
				length DIMENSION_TYPE_CD MEMBER_CD $32
					   include_member include_leaves include_rollups $1.;
				%let i=1;	
				%do %while(%scan(&varParNames,&i) ne %str());
					dimension_type_cd = "%scan(&varParNames,&i)";
					member_cd = "&version_consulta"; *<---Resolver que es esto;
					include_member = left("&&&im%scan(&varParNames,&i)");
					include_leaves = left("&&&il%scan(&varParNames,&i)");
					include_rollups = left("&&&ir%scan(&varParNames,&i)");
					output;
					%let i = %eval(&i+1);
				%end;
			run;
			
			***************Aqui se pasa el dataset por el fmquery**********;
			data work.fmquery_result_&nregla._&nmes; set work.queryparameters; run;
			***************************************************************;
			
			proc append base=work.fmquery_result_&nregla data=work.fmquery_result_&nregla._&nmes force; run;
		%end;

		proc append base=fmquery.fmquery_result_&periodo data=work.fmquery_result_&nregla; run;
	%end;

	/*data work.fmquery_result_final; *<----Comentado durante las pruebas;
		set work.fmquery_result_final;
		where value ne 0;
		new_version_code = upcase("&Version_Crear");
		transaction_amt_ytd_flg='Y';
		procesed_dttm = datetime();
		format value comma25.2 procesed_dttm datetime20.;
	run;*/
%mend;

%procesar_fmquery;