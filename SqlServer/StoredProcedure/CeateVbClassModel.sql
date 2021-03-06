USE DatabaseName
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[p_CreateModelVb] 
	@table_name nvarchar(128), -- table or view source
	@class_name nvarchar(128),  -- name of generated class
	@namespace nvarchar(128) = null  -- namespace of generated class
AS
BEGIN

	SET NOCOUNT ON;

	-- local variables
	declare @fieldname nvarchar(128)
	declare @fieldtype nvarchar(128)
	declare @nullable varchar(3)
	declare @ctor_sign nvarchar(4000)
	declare @ctor_body nvarchar(4000)

    -- definition table: field-name, field-type, field-nullable
	declare @field table (fieldname nvarchar(128), fieldtype nvarchar(128), nullable varchar(3))

	-- insert into table field-name, field-type, field-nullable
	insert into @field
	select 
			-- field-name
			c.COLUMN_NAME,
			-- field-type (conversion to Vb)
			case c.DATA_TYPE
				 when 'nvarchar' then 'String'
				 when 'varchar' then 'String'
				 when 'nchar' then 'String'
				 when 'ntext' then 'String'
				 when 'tinyint' then 'Byte'
				 when 'smallint' then 'Short'
				 when 'int' then 'Integer'
				 when 'bigint' then 'Long'
				 when 'bit' then 'Boolean'
				 when 'float' then 'Double'
				 when 'real' then 'Single'
				 when 'decimal' then 'Decimal'
				 when 'money' then 'Decimal'
				 when 'datetime' then 'Datetime'
				 when 'date' then 'Datetime'
				 when 'smalldatetime' then 'Datetime'
				 when 'varbinary' then 'Byte()'
				 when 'image' then 'Byte()'
				 when 'timestamp' then 'Byte()'
				 when 'uniqueidentifier' then 'Guid'
				 else @fieldtype
			  end
		   AS fieldtype,
		   -- field-nullable
		   case c.IS_NULLABLE when'YES' then '?' else '' end
		   AS nullable 
	from INFORMATION_SCHEMA.COLUMNS c
	where TABLE_NAME = @table_name 

	-- update field-type nullable column
	update @field set fieldtype=fieldtype + nullable where fieldtype<>'String' AND fieldtype<>'Byte()'

	-- declare cursor
	declare cur scroll cursor for
	select fieldname, fieldtype, nullable
	from @field

	-- open cursor
	open cur
	
	-- init class
	print 'Imports System.Data'
	print 'Imports System.Reflection'
	print ''

	-- name space
	if(@namespace IS NOT NULL)
		BEGIN
			print 'Namespace ' + @namespace
			print ''
		END


	print '<Serializable> _'
	print 'Public Class ' + @class_name
	print ''

	-- local variables
	print '#Region " Local variables "'
	print ''

	fetch next from cur
	into @fieldname, @fieldtype, @nullable
	while @@fetch_status = 0
		begin

		print 'Private _' + @fieldname + ' AS ' + @fieldtype

	    fetch next from cur
	    into @fieldname, @fieldtype, @nullable
	end

	print ''
	print '#End Region'

	-- proprietà
	print ''
	print '#Region " Public Property "'

	fetch first from cur
	into @fieldname, @fieldtype, @nullable

	set @ctor_sign = ''
	set @ctor_body = ''

	while @@fetch_status = 0
	begin

	   set @ctor_sign = @ctor_sign + 'ByVal p' + @fieldname + ' AS ' + @fieldtype + ', '
	   set @ctor_body = @ctor_body + CHAR(9) + '_' + @fieldname + ' = p' + @fieldname + CHAR(13)

	   print ''
	   print 'Public Property ' + @fieldname + '() AS ' + @fieldtype
	   print '   Get'
	   print '     return _' + @fieldname
	   print '   End Get'
	   print '   Set (value AS ' + @fieldtype + ')'
	   print '     _' + @fieldname + ' = value'
	   print '   End Set'
	   print 'End Property'

	   fetch next from cur
	   into @fieldname, @fieldtype, @nullable
	end

	print ''
	print '#End Region'

	-- close cursor
	close cur
	deallocate cur

	-- costruttori
	print ''
	print 'Public Sub New()'
	print 'End Sub'

	print ''
	print '    Public Sub New(' + substring(@ctor_sign, 0, len(@ctor_sign)) + ')'
	print ''
	print @ctor_body
	print ''
	print '    End Sub'

	print ''
	print '    Public Shared Function Create(record As IDataRecord) As ' + @class_name
	print ''
	print '        Return Procedure.Create(Of ' + @class_name + ')(record)'
	print ''
	print '    End Function'
	print ''
	print 'End Class'

	-- end namespace
	if(@namespace IS NOT NULL)
		BEGIN
			print ''
			print 'End Namespace'
		END


	print ''    
	print ''    
	print ''    
	print ''' ------ Insert into separate Module ------'    
	print ''    
	print 'Imports System.Data'
	print 'Imports System.Reflection'
	print ''    
	print 'Module Procedure'
	print ''    
	print '    Public Function Create(Of T)(record As IDataRecord) As T'
	print ''    
    print '        Dim ret As T = Activator.CreateInstance(Of T)'
	print ''    
    print '        For i As Integer = 0 To record.FieldCount - 1'
    print '            Dim fieldName As String = record.GetName(i)'
    print '            Dim value As Object = If(record.GetValue(i) Is DBNull.Value, Nothing, record.GetValue(i))'
    print '            Dim p As PropertyInfo = ret.GetType.GetProperty(fieldName, BindingFlags.Instance Or BindingFlags.Public Or BindingFlags.IgnoreCase)'
    print '            If p IsNot Nothing Then p.SetValue(ret, value, Nothing)'
    print '        Next'
	print ''    
    print '        Return ret'
	print ''    
    print '    End Function'
	print ''    
	print 'End Module'    


	END
