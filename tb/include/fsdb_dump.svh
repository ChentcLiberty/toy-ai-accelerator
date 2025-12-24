`ifndef __FSDB_DUMP_SVH__
`define __FSDB_DUMP_SVH__

// ------------------------------------------------------------
// Unified FSDB dump helper
// Enabled only when DUMP_FSDB is defined (from Makefile)
// ------------------------------------------------------------
`ifdef DUMP_FSDB

  initial begin
    string fsdb_name;

    // 默认文件名
    fsdb_name = "build/waves.fsdb";

    // 允许命令行覆盖：+fsdbfile=xxx.fsdb
    void'($value$plusargs("fsdbfile=%s", fsdb_name));

    $fsdbDumpfile(fsdb_name);

    // 推荐：限定在 TB 顶层，避免全量 dump
    `ifdef FSDB_TOP
      $fsdbDumpvars(0, `FSDB_TOP);
    `else
      // 兜底方案：全量 dump（不推荐但安全）
      $fsdbDumpvars(0);
    `endif

    $display("[FSDB] dumping enabled, file = %s", fsdb_name);
  end

`endif // DUMP_FSDB

`endif // __FSDB_DUMP_SVH__

