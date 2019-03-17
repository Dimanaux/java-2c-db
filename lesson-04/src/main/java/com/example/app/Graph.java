package com.example.app;

import java.util.List;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Random;

public class Graph {
    public static void main(String[] args) throws Exception {
        String url = "jdbc:neo4j:bolt://localhost:7687";
        String user = "neo4j";
        String password = "qwerty";
        Connection connection = DriverManager.getConnection(url, user, password);
        connection.setAutoCommit(false);

        // createTags(connection);
        // createResources(connection);
        createResourceTags(connection);
        connection.close();
    }

    static int TAGS_COUNT = 400;
    static int RESOURCES_COUNT = 1_000_000;
    static int PERCENT = RESOURCES_COUNT / 100;

    static void createTags(Connection connection) throws SQLException {
        PreparedStatement statement = connection.prepareStatement(
            "CREATE (:Tag {tagId: ?, name: ?});"
        );
        System.out.println("Creating tags...");
    
        for (int i = 1; i <= TAGS_COUNT; i++) {
            statement.setInt(1, i);
            statement.setString(2, "tag-" + i);
            statement.addBatch();
        }
        System.out.println();
        statement.executeBatch();
        connection.commit();
    }

    static void createResources(Connection connection) throws SQLException {
        PreparedStatement statement = connection.prepareStatement(
            "CREATE (:Resource {resourceId: ?, url: ?});"
        );
        for (int i = 1; i <= RESOURCES_COUNT; i++) {
            statement.setInt(1, i);
            statement.setString(2, "link-" + i);
            statement.addBatch();
            if (i % PERCENT == 0) {
                statement.executeBatch();
                connection.commit();
                statement.clearBatch();
            }
        }
        statement.executeBatch();
        connection.commit();
    }

    static void createResourceTags(Connection connection) throws SQLException {
        Random random = new Random();
        List<Integer> tags = new ArrayList<Integer>(TAGS_COUNT);
        for (int i = 1; i <= TAGS_COUNT; i++) {
            tags.add(i);
        }

        PreparedStatement statement = connection.prepareStatement(
            "MATCH (r:Resource {resourceId: ?}) MATCH (t:Tag {tagId: ?}) CREATE (r)-[:HAS]->(t), (t)-[:OWNED]->(r);"
        );
        for (int i = 1; i <= RESOURCES_COUNT; i++) {
            Collections.shuffle(tags, random);
            for (int j = random.nextInt(100) + 50; j > 0; j--) {
                statement.setInt(1, i);
                statement.setInt(2, tags.get(j));
                statement.addBatch();
            }
            if (i % 100 == 0) {
                statement.executeBatch();
                connection.commit();
                statement.clearBatch();
            }
        }
        statement.executeBatch();
        connection.commit();
    }
}
