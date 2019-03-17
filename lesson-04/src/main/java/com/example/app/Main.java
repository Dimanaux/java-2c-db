package com.example.app;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Random;

public class Main {
    public static void main(String[] args) throws Exception {
        String databaseName = "java";
        String username = "postgres";
        String password = "postgres";

        String url = String.format(
                "jdbc:postgresql://localhost/%s?user=%s&password=%s",
                databaseName, username, password
        );
        Connection connection = DriverManager.getConnection(url);
        connection.setAutoCommit(false);

        // fillResources(connection);
        // fillTags(connection);
        // fillResourceTag(connection);
    }

    static int RESOURCES_COUNT = 1_000_000;
    static int TAGS_COUNT = 400;
    static int BATCH_SIZE = 100; // * 100
    static Random random = new Random();
    static List<Integer> array = new ArrayList<>(400);
    static {
        for (int i = 1; i <= 400; i++) {
            array.add(i);
        }
    }

    static void fillResourceTag(Connection connection) throws Exception {
        PreparedStatement statement = connection.prepareStatement(
            "INSERT INTO resource_tag (resource_id, tag_id) VALUES (?, ?);"
        );

        for (int i = 1; i <= RESOURCES_COUNT; i++) {
            int tagsCount = 50 + random.nextInt(100);
            Collections.shuffle(array);
            for (int j = 0; j < tagsCount; j++) {
                statement.setInt(1, i);
                statement.setInt(2, array.get(j));
                statement.addBatch();
            }
            if (i % BATCH_SIZE == 0) {
                statement.executeBatch();
                connection.commit();
                statement.clearBatch();
            }
        }
        statement.executeBatch();
        connection.commit();
    }

    static void fillTags(Connection connection) throws Exception {
        PreparedStatement statement = connection.prepareStatement(
            "INSERT INTO tag (title) VALUES (?);"
        );

        for (int i = 1; i <= TAGS_COUNT; i++) {
            statement.setString(1, "tag" + i);
            statement.addBatch();
        }
        statement.executeBatch();
        connection.commit();
    }

    static void fillResources(Connection connection) throws Exception {
        PreparedStatement statement = connection.prepareStatement(
            "INSERT INTO resource (link) VALUES (?);"
        );

        for (int i = 1; i <= RESOURCES_COUNT; i++) {
            statement.setString(1, "res" + i);
            statement.addBatch();
        }
        statement.executeBatch();
        connection.commit();
    }
}
