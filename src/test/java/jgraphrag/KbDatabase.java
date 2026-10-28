package jgraphrag;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.testcontainers.containers.Container;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.containers.wait.strategy.Wait;
import org.testcontainers.images.builder.ImageFromDockerfile;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;
import org.testcontainers.utility.MountableFile;

import java.nio.file.Path;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Duration;
import java.util.List;
import java.util.Properties;

final class KbDatabase {

    static final String COMMIT = System.getProperty("kb.commit", "30b20cc0e2a6aebdd03125954134471b29a79e68");
    static final String LANCE_TAM_COMMIT = System.getProperty("lance_tam.commit", "4b3a776b30855f13a597cdfb6c1a212060c5055c");
    static final String LANCE_COMMIT = System.getProperty("lance.commit", "dc53d5d174af62c49ddd98d1024a64488c1e4404");
    static final String CORPUS = "habr";

    private static PostgreSQLContainer container;
    private static List<Corpus.Copied> corpus;
    private static GenericContainer<?> ollama;

    private KbDatabase() {
    }

    static synchronized PostgreSQLContainer get() throws Exception {
        if (container == null) {
            String image = new ImageFromDockerfile("jgraph-rag/pg-memory:" + COMMIT.substring(0, 12) + "-"
                    + LANCE_TAM_COMMIT.substring(0, 12), false)
                    .withFileFromClasspath("Dockerfile", "pg_memory/Dockerfile")
                    .withBuildArg("KB_COMMIT", COMMIT)
                    .withBuildArg("LT_COMMIT", LANCE_TAM_COMMIT)
                    .withBuildArg("LANCE_COMMIT", LANCE_COMMIT)
                    .get();
            PostgreSQLContainer c = new PostgreSQLContainer(DockerImageName.parse(image).asCompatibleSubstituteFor("postgres"))
                    .withDatabaseName(Lang.RU.database())
                    .withUsername("postgres")
                    .withPassword("postgres")
                    .withEnv("POSTGRES_HOST_AUTH_METHOD", "trust")
                    .withSharedMemorySize(4L << 30)
                    .withCommand("postgres", "-c", "shared_preload_libraries=pg_knowledge_base,lance_tam", "-c", "fsync=off",
                            "-c", "shared_buffers=2GB", "-c", "maintenance_work_mem=2GB",
                            "-c", "max_parallel_maintenance_workers=4");
            for (String f : new String[] {"data/habr_1097022.ru.sql", "data/habr_1097022.en.sql", "db/agent_roles.sql",
                    "db/corpus.sql", "db/corpus_indexes.sql", "db/corpus_roles.sql"}) {
                c.withCopyFileToContainer(MountableFile.forHostPath(Path.of(f), 0644), "/load/" + Path.of(f).getFileName());
            }
            c.start();
            psql(c, "postgres", "-c", "CREATE DATABASE " + Lang.EN.database());
            for (Lang lang : Lang.values()) {
                String db = lang.database();
                psql(c, db, "-c", "CREATE EXTENSION pg_knowledge_base");
                psql(c, db, "-f", "/load/habr_1097022." + lang.code() + ".sql");
                psql(c, db, "-f", "/load/agent_roles.sql");
                psql(c, db, "-c", "ANALYZE");
            }
            container = c;
        }
        return container;
    }

    static synchronized List<Corpus.Copied> corpus() throws Exception {
        if (corpus == null) {
            PostgreSQLContainer c = get();
            psql(c, "postgres", "-c", "CREATE DATABASE " + CORPUS);
            psql(c, CORPUS, "-c", "CREATE EXTENSION vector", "-c", "CREATE EXTENSION lance_tam", "-f", "/load/corpus.sql");
            try (Connection pg = connect(CORPUS, "postgres")) {
                corpus = Corpus.load(pg, Corpus.SOURCE, Corpus.PARTITIONS);
            }
            psql(c, CORPUS, "-f", "/load/corpus_indexes.sql", "-f", "/load/corpus_roles.sql", "-c", "ANALYZE");
        }
        return corpus;
    }

    static synchronized String ollama() {
        if (ollama == null) {
            String image = new ImageFromDockerfile("jgraph-rag/ollama-embeddinggemma:0.40.11", false)
                    .withFileFromClasspath("Dockerfile", "ollama/Dockerfile")
                    .get();
            GenericContainer<?> o = new GenericContainer<>(DockerImageName.parse(image))
                    .withExposedPorts(11434)
                    .waitingFor(Wait.forHttp("/api/tags").forPort(11434).withStartupTimeout(Duration.ofMinutes(2)));
            o.start();
            ollama = o;
        }
        return "http://" + ollama.getHost() + ":" + ollama.getMappedPort(11434);
    }

    static void psql(PostgreSQLContainer c, String db, String... args) throws Exception {
        String[] cmd = new String[8 + args.length];
        System.arraycopy(new String[] {"psql", "-X", "-q", "-v", "ON_ERROR_STOP=1", "-U", "postgres", "-d" + db}, 0, cmd, 0, 8);
        System.arraycopy(args, 0, cmd, 8, args.length);
        Container.ExecResult r = c.execInContainer(cmd);
        if (r.getExitCode() != 0) {
            throw new IllegalStateException(db + " " + String.join(" ", args) + ": " + r.getStderr());
        }
    }

    static String jdbcUrl(Lang lang) throws Exception {
        return jdbcUrl(lang.database());
    }

    static String jdbcUrl(String database) throws Exception {
        PostgreSQLContainer c = get();
        return "jdbc:postgresql://" + c.getHost() + ":" + c.getMappedPort(PostgreSQLContainer.POSTGRESQL_PORT) + "/" + database;
    }

    static Connection connect(Lang lang, String user) throws Exception {
        return connect(lang.database(), user);
    }

    static Connection connect(String database, String user) throws Exception {
        Properties p = new Properties();
        p.setProperty("user", user);
        p.setProperty("password", "postgres");
        return DriverManager.getConnection(jdbcUrl(database), p);
    }

    static JsonNode sparql(Connection c, String query) throws SQLException {
        try (PreparedStatement ps = c.prepareStatement("SELECT kb.sparql_json(?, ?)::text")) {
            ps.setString(1, query);
            ps.setString(2, MemoryServer.BASE);
            try (ResultSet rs = ps.executeQuery()) {
                rs.next();
                return new ObjectMapper().readTree(rs.getString(1));
            } catch (com.fasterxml.jackson.core.JsonProcessingException e) {
                throw new SQLException(e);
            }
        }
    }

    static String dump(Lang lang) throws Exception {
        try (Connection c = connect(lang, "postgres");
             ResultSet rs = c.createStatement().executeQuery("SELECT kb.dump('nquads', NULL, true)")) {
            rs.next();
            return rs.getString(1);
        }
    }
}
