// ------------------------------------------------------------
// Unified FSDB dump helper
// Enabled only when DUMP_FSDB is defined (from Makefile)
// ------------------------------------------------------------
`ifdef DUMP_FSDB

  initial begin
    string fsdb_name;

    // 默认值（会被命令行 +fsdbfile= 覆盖）
    fsdb_name = "build/default.fsdb";

    if (!$value$plusargs("fsdbfile=%s", fsdb_name)) begin
      $display("[FSDB] Warning: No +fsdbfile specified, using default");
    end

    $fsdbDumpfile(fsdb_name);

    `ifdef FSDB_TOP
      $fsdbDumpvars(0, `FSDB_TOP);
    `else
      $fsdbDumpvars(0);
    `endif

    $display("[FSDB] dumping to: %s", fsdb_name);
  end

`endif // DUMP_FSDB
