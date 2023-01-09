USE DRA_V22
GO
/****** Object:  StoredProcedure [dbo].[PA_HD_WEB_OC_Rechaza]    Script Date: 09/01/2023 13:02:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[PA_HD_WEB_OC_Rechaza]
@p_CodCia as Smallint, @p_CodSuc as Smallint, @p_NumOC as int, @p_CodUsr as int, @p_Motivo as varchar(200)
/***********************************************************************************************************
 Procedimiento	: PA_HD_WEB_OC_Rechaza
 Proposito		: Ejecuta el RECHAZO de la OC en el nivel del usuario y marca la OC como Rechazada
 Inputs			: p_CodCia, p_CodSuc, p_NumOC, p_CodUsr, p_Motivo
 Se asume		: RQ existe en Tablas y Ya existe Validacion de acceso al RQ
 Efectos		: Retorno 1 registro con Indicacion de EXITO 1 o FALLO 0
 Retorno		: 1 Registro con 2 Columnas
 Notas			: N/A
 Modificaciones	: 
 Autor			: Narvasta Sergio
 Fecha y Hora	: 09/01/2023
***********************************************************************************************************/
AS
SET NOCOUNT ON

Declare @n_NumNiv Tinyint, @n_NivUsr Tinyint, @n_Item Tinyint, @n_NumVis Tinyint  
Declare @s_mensaje Varchar(200), @c_numscc varchar(10)
Set @n_Item   = 0
Set @n_NumNiv = 0
Set @n_NumVis = 0

-- Identificar el Ultimo Nivel de Aprobacion de OC
Select @n_NumNiv = COUNT(*) From REQ_APROB_ORDCOM_AOC
where cia_codcia=@p_CodCia and occ_codepk=@p_NumOC and aoc_indapr=0
-- Si es UNO entonces es el ultimo nivel y se aprueba OC
If @@ERROR <> 0 
Begin
	Set @s_mensaje = 'Error al Consultar datos de los Niveles de RECHAZO de OC ' 
	Raiserror(@s_mensaje,16,1)
	Select -4 as Cod_Resultado, @s_Mensaje as Des_Resultado
	Return -4
End

If @n_NumNiv<=0
Begin
   Set @s_mensaje = 'No hay niveles pendientes de RECHAZO de OC '
   Select -3 as Cod_Resultado, @s_Mensaje as Des_Resultado
   Return -3
End

Select @n_NivUsr = COUNT(*) from REQ_APROB_ORDCOM_AOC 
Where cia_codcia=@p_CodCia and suc_codsuc=@p_CodSuc and occ_codepk=@p_NumOC and uap_codepk=@p_CodUsr and aoc_indapr=0
If Isnull(@n_NivUsr,0)<=0
Begin
   Set @s_mensaje = 'No hay niveles pendientes de RECHAZO de OC para el USUARIO'
   Select 0 as Cod_Resultado, @s_Mensaje as Des_Resultado
   Return 0
End
/*
-- Identificar la Solicitud de Compra 
Select @c_numscc = scc_numscc from ORDEN_COMPRA_OCC
Where cia_codcia=@p_CodCia and suc_codsuc=@p_CodSuc and ocm_corocm=@p_NumOC
If Len(Isnull(@c_NumScc,''))<=0
Begin
   Set @s_mensaje = 'NO hay Solicitud de Compra relacionada con esta Orden de Compra, revise tabla de Solicitud de Compra'
   Select -6 as Cod_Resultado, @s_Mensaje as Des_Resultado
   Return -6
End
 */
Begin Transaction APRUEBA

-- Aprobar en el nivel del Usuario
-- Select * From APROBAC_REQCOM_APROBACIONES_ARA
Update REQ_APROB_ORDCOM_AOC Set aoc_indapr=1
Where cia_codcia=@p_CodCia and suc_codsuc=@p_CodSuc and occ_codepk=@p_NumOC
and uap_codepk=@p_CodUsr and anm_codanm = 
(Select min(anm_codanm) from REQ_APROB_ORDCOM_AOC 
 Where cia_codcia=@p_CodCia and suc_codsuc=@p_CodSuc and occ_codepk=@p_NumOC and uap_codepk=@p_CodUsr and aoc_indapr=0)
 
If @@ERROR <> 0 
Begin
	Set @s_mensaje = 'Error al RECHAZAR la Orden de Compra tabla APROBAC_ORDCOM_APROBACIONES_AOA ' 
	Raiserror(@s_mensaje,16,1)
	Rollback Transaction APRUEBA
	Select -2 as Cod_Resultado, @s_Mensaje as Des_Resultado
	Return -2
End

-- Aprobar OC
-- 1 => Pendiente / 2 => Aprobado / 3 => Rechazado
Update OCOMPRA_OCC Set occ_sitapr='3'
Where cia_codcia=@p_CodCia and suc_codsuc=@p_CodSuc and occ_codepk=@p_NumOC
If @@ERROR <> 0 
   Begin
    	Set @s_mensaje = 'Error al RECHAZAR cabecera de Orden de Compra ORDEN_COMPRA_OCC ' 
    	Raiserror(@s_mensaje,16,1)
    	Rollback Transaction APRUEBA
    	Select -1 as Cod_Resultado, @s_Mensaje as Des_Resultado
    	Return -1
   End
   
-- Cuando se Rechaza Totalmente se coloca el nivel en 0
   If Len(Isnull(@c_NumScc,''))>0
   Begin
      Update Solicitud_Compra_Scc Set scc_indfir='0'
      Where cia_codcia=@p_CodCia and suc_codsuc=@p_CodSuc and scc_numscc=@c_numscc
   End
   If @@ERROR <> 0 
   Begin
    	Set @s_mensaje = 'Error al Actualizar indicador de Firma de Solicitud de compra relacionada SOLICITUD_COMPRA_SCC ' 
    	Raiserror(@s_mensaje,16,1)
    	Rollback Transaction APRUEBA
    	Select -1 as Cod_Resultado, @s_Mensaje as Des_Resultado
    	Return -1
   End
   
-- Insertar Motivo de RECHAZO del RQ
SELECT @n_Item=MAX(mdc_secaci) from REQ_MOTIVO_DEVCOM_MDC Where cia_codcia=@p_CodCia and suc_codsuc=@p_CodSuc and occ_codepk=@p_NumOC
Set @n_Item = isnull(@n_Item,0) + 1
INSERT INTO REQ_MOTIVO_DEVCOM_MDC(cia_codcia,suc_codsuc,occ_codepk,mdc_secaci,mdc_fecmdr,uap_codepk,mdc_tipmdr,mdc_motmdr,mdc_estado,mdc_usucre,mdc_feccre,mdc_usuact,mdc_fecact) 
Values (@p_CodCia,@p_CodSuc,@p_NumOC,@n_Item,getdate(),@p_CodUsr,'0',@p_Motivo,'1',SYSTEM_USER,getdate(),SYSTEM_USER,getdate()) 
If @@ERROR <> 0 
Begin
  	Set @s_mensaje = 'Error al Insertar MOTIVO de RECHAZO MOTIVO_DEVREC_COMPRAS_MDC' + char(13) + ERROR_MESSAGE();
  	Raiserror(@s_mensaje,16,1)
  	Rollback Transaction APRUEBA
   	Select -5 as Cod_Resultado, @s_Mensaje as Des_Resultado
   	Return -5;
End				
/*
Insert into COMPRAS_LOCALES_AUDITORIA_CLA (CIA_CODCIA, CLA_FECCLA, CLA_DESCLA, S10_CODUSU, CLA_MOTCLA, CLA_TIPCLA)
Values (@p_CodCia,GETDATE(),'RECHAZO DE LA ORDEN DE COMPRA: '+@p_NumOC,current_user,@p_Motivo,'O')
If @@ERROR <> 0 
Begin
  	Set @s_mensaje = 'Error al actualizar AUDITORIA de RECHAZO COMPRAS_LOCALES_AUDITORIA_CLA ' 
  	Raiserror(@s_mensaje,16,1)
  	Rollback Transaction APRUEBA
   	Select -6 as Cod_Resultado, @s_Mensaje as Des_Resultado
   	Return -6
End	
*/
Commit Transaction APRUEBA
/*
-- Enviar MAIL de RECHAZO
Exec PA_HD_WEB_OC_Envio_Mail @p_CodCia=@p_CodCia, @p_CodSuc=@p_CodSuc, @p_NumOC=@p_NumOC, @p_TipAvi=1, @p_Motivo=@p_Motivo, @p_User_Envia=@p_CodUsr
If @@ERROR <> 0 
Begin
  	Set @s_mensaje = 'Error al enviar mail de RECHAZO ' 
  	Raiserror(@s_mensaje,16,1)
  	Rollback Transaction APRUEBA
   	Select -7 as Cod_Resultado, @s_Mensaje as Des_Resultado
   	Return -7
End				
*/
Select 1 as Cod_Resultado, 'RECHAZO EXITOSO' as Des_Resultado

Return

/*
Exec PA_HD_WEB_OC_Rechaza @p_CodCia='01', @p_CodSuc='01', @p_NumRQ='2015010002', @p_CodUsr='AMADE'
--'CARRL7'
--'AMADE' 
*/

