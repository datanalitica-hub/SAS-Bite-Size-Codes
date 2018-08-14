/************************************************************************************************************/
/* Autor: Fernando Gonzalez                                                                                 */
/* Fecha: 13/08/2018 				                                                                        */
/* Fecha de Modificación: 00/00/0000 Autor Modificación:                                                    */
/* Descripción: Código utilizado para buscar valores especificos en todas las tablas de una librería.       */
/*   		El resultado se imprime en la pantalla de output de SAS. Solo se imprimen los que coinciden.    */
/* Modificaciones pendientes: 																				*/
/* 			-Hacerlo menos especifico.																		*/
/************************************************************************************************************/

%macro busca071();
%let tablas = ;
%let nombre_campo =;
proc sql noprint;
	select memname, name into :tablas separated by ',', :nombre_campo separated by ',' from DICTIONARY.COLUMNS 
		where upcase(libname) = 'STAGEPM' and upcase(name) in ('ORGANIZACION', 'ORGANIZACION_ORIGINAL') 
		and memtype ne 'VIEW';
quit;

%let i=1;
%do %while (%scan("&tablas", &i, ",") ^=%str());
	title1 %scan("&tablas", &i, ",");
	proc sql;
		select * from STAGEPM.%scan("&tablas", &i, ",") where %scan("&nombre_campo", &i, ",") = '071313';
	quit;
	%let i = %eval(&i + 1);
%end;
%mend;

%busca071;