/*
  Fixes profile deletion after adding the permission foreign key.
  The dependent permission links must be deleted before the profile row.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

ALTER PROCEDURE [dbo].[SP_TB_PERFIL_DELETE]
    @CODPERFIL int
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRANSACTION;

    DELETE FROM dbo.TB_PERFILPERMISSOES_NEW
    WHERE CODPERFIL = @CODPERFIL;

    DELETE FROM dbo.TB_PERFIL
    WHERE CODPERFIL = @CODPERFIL;

    COMMIT TRANSACTION;

    RETURN @CODPERFIL;
END;
GO
