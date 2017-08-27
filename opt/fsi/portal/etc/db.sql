CREATE TABLE IF NOT EXISTS "entries" (
  "id" SERIAL,
  "db_srv" text NOT NULL UNIQUE,
  "db_typ" text NOT NULL,
  "db_mac" text NOT NULL UNIQUE,
  "db_control" text NOT NULL,
  "db_controltyp" text NOT NULL CHECK(db_controltyp IN('xp','vc','srv','lx')),
  "mgmt_ip" text NOT NULL UNIQUE,
  "mgmt_user" text NOT NULL,
  "mgmt_pwc" text NOT NULL,
  "mgmt_pw" text NOT NULL,
  "rc_type" text,
  "rc_icon" text,
  "rc_desc" text,
  "rc_http" text,  
  "rc_ssh" text, 
  "srv_type" text NOT NULL CHECK(srv_type IN('ssh','rdp','none')),
  "srv_cmd" text,  
  "s_online" text,
  "s_inststart" text,
  "s_insterr" text,
  "s_block" text,
  "block_user" text,
  "s_msg" text,
  "s_instrun" text,
  "s_instwait" text,
  "s_xenmaster" text,
  "s_xenha" text,
  "s_patchlevel" text,
  "s_patchlevels" text,
  "j_inst" text,
  "j_logshow" text,
  "x_poolcount" text,
  CONSTRAINT srv_entries PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "status" (
  "id" SERIAL,
  "short" text NOT NULL,
  "long" text NOT NULL,
  "jobuser" text NOT NULL,
  "url" text NOT NULL,
  "logdatei" text NOT NULL,
  "control" text NOT NULL,
  "ctyp" text NOT NULL,
  "block" text NOT NULL,
  CONSTRAINT task_status PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "workstat" (
  "typ" text NOT NULL CHECK(typ IN('xp','vc','srv','lx')),
  "who" text NOT NULL UNIQUE,
  "status" text NOT NULL,
  "info" text NOT NULL,
  CONSTRAINT worker_status PRIMARY KEY ("who")
);

CREATE TABLE IF NOT EXISTS "daemonstat" (
  "daemon" text NOT NULL UNIQUE CHECK(daemon IN('online','all')),
  "status" text NOT NULL CHECK(status IN('off','running','sleeping')),
  CONSTRAINT daemon_status PRIMARY KEY ("daemon")
);
