-- Instala SOMENTE o diário/counters do VettiFlow. Não altera tabelas ERP.
-- Executar com acesso exclusivo à base HMLp12. Não executar em produção.
SET XACT_ABORT ON;
IF DB_NAME() <> N'HMLp12'
    THROW 51000, 'Esta migracao exige a base HMLp12.', 1;
BEGIN TRANSACTION;
DECLARE @lock int;
EXEC @lock=sys.sp_getapplock @Resource=N'VettiFlow.SQL.DEV.v1',
    @LockMode='Exclusive', @LockOwner='Transaction', @LockTimeout=5000;
IF @lock < 0
BEGIN
    ROLLBACK TRANSACTION;
    THROW 51001, 'Fluxo DEV ocupado.', 1;
END;
IF OBJECT_ID(N'dbo.VF_SQL_VERSION', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.VF_SQL_VERSION(version int NOT NULL PRIMARY KEY CHECK(version=1));
    INSERT INTO dbo.VF_SQL_VERSION VALUES(1);
END;
IF OBJECT_ID(N'dbo.VF_SQL_REQUESTS', N'U') IS NULL
    CREATE TABLE dbo.VF_SQL_REQUESTS(
        id varchar(100) COLLATE Latin1_General_100_BIN2 NOT NULL PRIMARY KEY,
        fingerprint char(64) NOT NULL,
        result nvarchar(max) NOT NULL CHECK(ISJSON(result)=1),
        created_at datetime2 NOT NULL DEFAULT SYSUTCDATETIME()
    );
IF OBJECT_ID(N'dbo.VF_SQL_ORDERS', N'U') IS NULL
    CREATE TABLE dbo.VF_SQL_ORDERS(
        op varchar(14) NOT NULL PRIMARY KEY,
        manifest nvarchar(max) NOT NULL CHECK(ISJSON(manifest)=1)
    );
IF OBJECT_ID(N'dbo.VF_SQL_COUNTERS', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.VF_SQL_COUNTERS(
        kind varchar(12) NOT NULL PRIMARY KEY CHECK(kind IN ('order','movement')),
        value int NOT NULL CHECK(value BETWEEN 0 AND 99999)
    );
    INSERT INTO dbo.VF_SQL_COUNTERS VALUES('order',0),('movement',0);
END;
COMMIT TRANSACTION;
-- Rollback operacional: desativar VF_SQL_WRITE_ENABLED. Não apagar diário ou
-- counters após uso: perder esses dados remove a proteção contra duplicidade.
