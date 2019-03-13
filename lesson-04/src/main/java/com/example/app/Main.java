package com.example.app;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.SQLException;
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

        Class.forName("org.postgresql.Driver");
        Connection connection = DriverManager.getConnection(url);

        fillResources(connection);
        System.out.println("resources loaded.");
        fillTags(connection);
        System.out.println("tags loaded.");
        fillResourceTag(connection);
        System.out.println("resource-tags loaded.");
    }

    private static final int RESOURCES_COUNT = 1_000_000;
    private static final int TAGS_COUNT = 400;

    private static void fillResourceTag(Connection connection) throws SQLException {
        Random random = new Random();

        List<Integer> array = new ArrayList<>(400);
        for (int i = 1; i <= 400; i++) {
            array.add(i);
        }

        connection.setAutoCommit(false);

        final PreparedStatement statement = connection.prepareStatement("INSERT INTO resource_tag (resource_id, tag_id) VALUES (?, ?);");

        for (int i = 1; i <= RESOURCES_COUNT; i++) {
            int tagsCount = 50 + random.nextInt(100);
            Collections.shuffle(array);
            for (int j = 0; j < tagsCount; j++) {
                statement.setInt(1, i);
                statement.setInt(2, array.get(j));
                statement.addBatch();
            }
            if (i % 10000 == 0) {
                statement.executeBatch();
                connection.commit();
            }
        }

        statement.executeBatch();
        connection.commit();
    }

    private static void fillTags(Connection connection) throws SQLException {
        connection.setAutoCommit(false);

        final PreparedStatement statement = connection.prepareStatement("INSERT INTO tag (title) VALUES (?);");

        for (int i = 1; i <= TAGS_COUNT; i++) {
            statement.setString(1, "tag" + i);
            statement.addBatch();
        }

        statement.executeBatch();
        connection.commit();
    }

    private static void fillResources(Connection connection) throws SQLException {
        connection.setAutoCommit(false);

        final PreparedStatement statement = connection.prepareStatement("INSERT INTO resource (link) VALUES (?);");

        for (int i = 1; i <= RESOURCES_COUNT; i++) {
            statement.setString(1, "res" + i);
            statement.addBatch();
        }

        statement.executeBatch();
        connection.commit();
    }
}
