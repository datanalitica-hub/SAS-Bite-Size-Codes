options mprint mlogic;

libname smt "&path";
filename resp "C:\Users\datanalitica\Documents\Fernando\DatAnalitica\prueba.json";

%global survey_id;
%let survey_id=;

%macro connect_sm(url_connect);
	proc http 
	   url="&url_connect"
	   out=resp;

	   headers "Authorization" =  "Bearer &key"
	   		   "Content-Type" = "application/json"
			   "charset" = "iso-8859-1"; /*No ha logrado servir*/
	run;
%mend;

%macro extraer_survey_id;
	*Se guarda la info del json en una libreria temporal;
	libname sm_gen JSON fileref=resp;

	*Se extrae el Survey_ID de la survey cuyo nombre se ingreso;
	data _null_;
		set sm_gen.data;
		if upcase(compress(title,,"ps")) = upcase(compress("&survey_name",,"ps")) then
			call symputx ('survey_id', id);
	run;
	
	*proc print data=sm_gen.DATA;run;
%mend;

%macro obtener_survey_stru;
	%local qstn_matrix;
	
	libname srv_str JSON fileref=resp;

	proc print data=srv_str.alldata;run;

	data structure_survey;
		retain qstn_n ans_n 0 qstn_matrix matrix_ans_n;
		set srv_str.alldata(where=(p2='questions'));
		if p = 2 then qstn_n+1;

		if p3 = 'id' then qstn_id = value;
		else if p4 = 'heading' then qstn_name = value;
		else if p3 = 'family' then do; 
			qstn_family = value;
			if qstn_family = 'matrix' then do; qstn_matrix = 1; ; end;
			else if not(qstn_family in ('matrix', ' ')) then do; qstn_matrix = 0; end;	
		end;
		
		else if p3 = 'answers' then do;	
			if qstn_matrix = 1 then do;
				if p = 4 and p4='rows' then ans_n+1;
				if p4='rows' and p5='text' then  ans_text = value;
				else if p4='rows' and p5='id' then ans_id = value;
				
				if p = 4 and p4='choices' then matrix_ans_n+1;
				else if p4='choices' and p5 = 'text' then matrix_ans_text = value;
				else if p4='choices' and p5 = 'id' then matrix_ans_id = value; 
			end;
			else do;
				if p = 4 then ans_n+1;
				if p5='text' then ans_text = value;	
				else if p5='id' then ans_id = value;
			end;
		end;
		
		keep qstn_n qstn_id qstn_name qstn_family ans_n ans_text ans_id matrix_ans_n matrix_ans_text matrix_ans_id;
	run;

	proc sql;
		create table smt.structure_questions as
		select max(qstn_id) as qstn_id,
			   max(qstn_name) as qstn_name,
			   max(qstn_family) as qstn_family
		from structure_survey group by qstn_n;

		create table structure_answers as
		select max(ans_id) as ans_id,
			   max(ans_text) as ans_text,
			   max(qstn_id) as qstn_id,
			   qstn_n
		from structure_survey group by qstn_n, ans_n;

		create table structure_matrix_answers as
		select max(matrix_ans_id) as matrix_ans_id,
			   max(matrix_ans_text) as matrix_ans_text,
			   max(qstn_id) as qstn_id,
			   qstn_n, matrix_ans_n
		from structure_survey group by qstn_n, matrix_ans_n;
	quit;
	
	proc sort data=structure_answers; by qstn_n descending qstn_id; run;

	data smt.structure_answers;
		retain qstn_id_r;
		set structure_answers(where=(ans_id ne ' '));
		by qstn_n;
		if first.qstn_n then qstn_id_r = qstn_id;
		else qstn_id = qstn_id_r;
		drop qstn_id_r qstn_n;
	run;

	proc sort data=structure_matrix_answers; by qstn_n descending qstn_id; run;

	data smt.structure_matrix_answers;
		retain qstn_id_r;
		set structure_matrix_answers(where=(matrix_ans_id ne ' '));
		by qstn_n;
		if first.qstn_n then qstn_id_r = qstn_id;
		else qstn_id = qstn_id_r;
		drop qstn_id_r qstn_n;
	run;
%mend;

%macro obtener_survey_respuestas;
	libname srv_ans JSON fileref=resp;

	proc print data=srv_ans.alldata;run;

	data customer_answers;
		retain customer_n ans_n 0 customer_id ans_id;
		length email $32.;
		set srv_ans.alldata(where=(p1 = 'data'));
		if p = 2 and p2 = 'ip_address' then customer_n+1;
		
		email = 'NO POSE/NO RECOGE'; *<-No todas las encuestas lo tienen;
		if p2='id' then customer_id = value;
		else if p2 = 'ip_address' then ip_address = value;
		else if p2 = 'date_modified' then date = value;
		else if p2 = 'response_status' then srv_status = value;
		else if p4 = 'email' and p5 = 'value' then email = value;
		else if p3 = 'questions' then do;			
	 		if p4='id' then do; ans_id = value; ans_n+1; end;
			else if p5 = 'text' then customer_ans_1lvl = value;
			else if p5 = 'row_id' then customer_ans_2lvl = value;
			else if p5 = 'choice_id' then customer_ans_3lvl = value;
		end;

		if customer_n = 0 then delete;
		
		keep customer_n ans_n customer_id ip_address email date srv_status ans_id customer_ans_1lvl
																customer_ans_2lvl customer_ans_3lvl;
	run;

	proc sql;
		create table smt.customer_info as
		select max(customer_id) as customer_id,
			   max(ip_address) as ip_address,
			   max(email) as email,
			   max(date) as date,
			   max(srv_status) as srv_status
		from customer_answers group by customer_n;

		/*create table customer_ans as
		select max(ans_id) as qstn_id,
			   customer_ans_1lvl,
			   customer_ans_2lvl,
			   customer_ans_3lvl,
			   max(customer_id) as customer_id
		from customer_answers group by customer_n, ans_n;*/
	quit;

	data smt.customer_answers;
		length ans1 ans2 ans3 $32.;
		retain q_id c_id ans1 ans2 ans3 miss;
		set customer_answers(where=(customer_ans_1lvl ne '' or customer_ans_2lvl ne '' 
									or customer_ans_3lvl ne ''));
		rename ans_id = qstn_id;
		
		if c_id = customer_id then do;
			if q_id = ans_id then do;
				if miss > 1 then do; 
					if customer_ans_1lvl = ' ' and ans1 ne ' ' then	customer_ans_1lvl = ans1;
					if customer_ans_2lvl = ' ' and ans2 ne ' ' then	customer_ans_2lvl = ans2;
					if customer_ans_3lvl = ' ' and ans3 ne ' ' then	customer_ans_3lvl = ans3;
				end;
				else do;
					ans1 = customer_ans_1lvl;
					ans2 = customer_ans_2lvl;
					ans3 = customer_ans_3lvl;
					borrar = 1;
				end;
				miss = cmiss(customer_ans_1lvl, customer_ans_2lvl, customer_ans_3lvl);
			end;
			else do;
				q_id = ans_id;
				ans1 = customer_ans_1lvl;
				ans2 = customer_ans_2lvl;
				ans3 = customer_ans_3lvl;
				miss = cmiss(customer_ans_1lvl, customer_ans_2lvl, customer_ans_3lvl);
			end;
		end;
		else do;
			c_id = customer_id;
			q_id = ans_id;
			ans1 = customer_ans_1lvl;
			ans2 = customer_ans_2lvl;
			ans3 = customer_ans_3lvl;
			miss = cmiss(customer_ans_1lvl, customer_ans_2lvl, customer_ans_3lvl);
		end;
		
		if borrar = 1 then delete;
		keep ans_id customer_ans_1lvl customer_ans_2lvl customer_ans_3lvl customer_id;
	run;

	/*proc sort data=customer_ans; by customer_id qstn_id descending customer_ans_1lvl 
									descending customer_ans_2lvl descending customer_ans_3lvl; run;
	proc sort data=customer_ans nodupkey; by customer_id qstn_id customer_ans_3lvl; run; */
%mend;


%macro construir_tabla_final;
	
	proc sql;
		create table smt.resultados_&survey_id as
		select t2.customer_id,
			   t2.ip_address,
			   t2.email,
			   t2.date,
			   t2.srv_status,
			   t3.qstn_id,
			   t3.qstn_name,
			   t3.qstn_family,			
			   t1.customer_ans_1lvl,
			   t1.customer_ans_2lvl,
			   (t6.ans_text) as matrix_ans_text_2lvl,
			   t1.customer_ans_3lvl,
			   (t4.ans_text) as choices_ans_text,
			   (t5.matrix_ans_text) as matrix_ans_text_3lvl
		from smt.customer_answers t1
		left join smt.customer_info t2 on (t1.customer_id = t2.customer_id)
		left join smt.structure_questions t3 on (t1.qstn_id = t3.qstn_id)
		left join smt.structure_answers t4 on (t1.customer_ans_3lvl = t4.ans_id)
		left join smt.structure_matrix_answers t5 on (t1.customer_ans_3lvl = t5.matrix_ans_id)
		left join smt.structure_answers t6 on (t1.customer_ans_2lvl = t6.ans_id);
	quit;

	proc sort data=smt.resultados_&survey_id; by customer_id qstn_id; run;

	data smt.resultados_&survey_id; 
		set smt.resultados_&survey_id;
		if qstn_family = 'matrix' and (customer_ans_2lvl = ' ' or customer_ans_3lvl = ' ') then delete;
		else if qstn_family = 'demographic' and (customer_ans_1lvl = ' ' or customer_ans_2lvl = ' ') then delete; 

		if qstn_family in ('multiple_choice', 'single_choice') then customer_ans_1lvl = choices_ans_text;
		else if qstn_family = 'matrix' then do; 
			customer_ans_1lvl = matrix_ans_text_2lvl;
			customer_ans_2lvl = matrix_ans_text_3lvl;
		end;
		else if qstn_family = 'demographic' then do;
			customer_ans_2lvl = customer_ans_1lvl;
			customer_ans_1lvl = matrix_ans_text_2lvl;
		end;

		drop matrix_ans_text_2lvl customer_ans_3lvl choices_ans_text matrix_ans_text_3lvl;
	run;
	
	
	proc datasets library=smt nodetails nolist;
		modify resultados_&survey_id / correctencoding='iso88591' ;
	quit;

	proc datasets library=smt nodetails nolist;
		modify resultados_&survey_id / correctencoding='utf8' ;
	quit;
%mend;

%connect_sm(https://api.surveymonkey.com/v3/surveys);
%extraer_survey_id;
%connect_sm(https://api.surveymonkey.com/v3/surveys/&survey_id./details);
%obtener_survey_stru;
%connect_sm(https://api.surveymonkey.com/v3/surveys/&survey_id./responses/bulk);
%obtener_survey_respuestas;
%construir_tabla_final;

proc sql;
	select count(distinct(customer_id)) from smt.resultados_&survey_id; 
quit;