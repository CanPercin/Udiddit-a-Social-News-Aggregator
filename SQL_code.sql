CREATE TABLE "users" (
    "id" SERIAL PRIMARY KEY,
    "username" VARCHAR(25) UNIQUE NOT NULL,
    CONSTRAINT "username_prevent_null_chars" CHECK(LENGTH(TRIM("username"))>0));

CREATE TABLE "topics" (
    "id" SERIAL PRIMARY KEY,
    "topic_name" VARCHAR(30) UNIQUE NOT NULL,
        CONSTRAINT "topic_name_prevent_null_chars" CHECK(LENGTH(TRIM("topic_name"))>0),
    "description" VARCHAR(500));

CREATE TABLE "posts" (
    "id" SERIAL PRIMARY KEY,
    "user_id" INTEGER 
    REFERENCES "users" ON DELETE SET NULL,
    "topic_id" INTEGER NOT NULL
    REFERENCES "topics" ON DELETE CASCADE,
    "url" VARCHAR(4000),
    "text_content" VARCHAR(3000),
    "title" VARCHAR(100) NOT NULL,
    CONSTRAINT "title_prevent_null_chars"
    CHECK(LENGTH(TRIM("title"))>0),
    CONSTRAINT "title_check_URL&TEXTCONTENT"
    CHECK(
        (("url") IS NULL AND ("text_content") IS NOT NULL)
    OR
        (("url") IS NOT NULL AND ("text_content") IS NULL)
    )
);

CREATE TABLE "comments" (
    "id" SERIAL PRIMARY KEY,
    "user_id" INTEGER REFERENCES "users" ON DELETE SET NULL,
    "text_content" VARCHAR(1000) NOT NULL 
    CHECK(LENGTH(TRIM("text_content"))>0),
    "post_id" INTEGER REFERENCES "posts" ON DELETE CASCADE,
    "parent_id" INTEGER,
    CONSTRAINT "child_thread" FOREIGN KEY ("parent_id") REFERENCES "comments"("id") ON DELETE CASCADE
);



CREATE TABLE "votes" (
    "id" SERIAL PRIMARY KEY,
    "user_id" INTEGER REFERENCES "users" ON DELETE SET NULL,
    "post_id" INTEGER REFERENCES "posts" ON DELETE CASCADE,
    "vote" SMALLINT NOT NULL CHECK(vote=1 OR vote=-1)
    );

ALTER TABLE "votes" ADD CONSTRAINT
    "single_vote_for_a_post" UNIQUE("user_id","post_id");

ALTER TABLE "users" ADD last_logon TIMESTAMP;
ALTER TABLE "posts" ADD post_time TIMESTAMP;
ALTER TABLE "comments" ADD comment_time TIMESTAMP;


--Optimizing "Find all posts that link to a specific URL, for moderation purposes"
CREATE INDEX "find_url" ON "posts"("url");

--Optimizing "List all users who haven't logged in the last year"
CREATE INDEX "not_logged_for_a_year" ON "users"("username","last_logon");

--Optimizing "List the latest 20 posts for a given topic"
CREATE INDEX "f_post_time&topic_id" ON "posts"("post_time","topic_id");

--Optimizing "List the latest 20 posts made by a given user"
CREATE INDEX "f_user_id&topic_id" ON "posts"("user_id","topic_id");

--Optimizing "List all the top-level comments for a given post"
CREATE INDEX "top_level_comments_in_a_post" ON "comments"("text_content","post_id","parent_id") WHERE "parent_id" is NULL;

--Optimizing "List all the direct children of a parent comment"
CREATE INDEX "direct_children_of_a_comment" ON "comments"("text_content","parent_id");

--Optimizing "List the latest 20 comments made by a given user"
CREATE INDEX "last_20_comment_of_userid" ON "comments"("text_content","user_id");

--Optimizing "Compute the score of a post, defined as the difference between the number of upvotes and the number of downvotes"
CREATE INDEX "score_of_a_post" ON "votes"("vote","post_id");

INSERT INTO "users"("username")
WITH all_distinct_usernames AS (
    SELECT username FROM "bad_posts"
    UNION
    SELECT username FROM "bad_comments"
    UNION
    SELECT REGEXP_SPLIT_TO_TABLE(upvotes, ',') as username FROM "bad_posts"
    UNION
    SELECT REGEXP_SPLIT_TO_TABLE(downvotes, ',') as username FROM "bad_posts")
SELECT username
FROM all_distinct_usernames;

INSERT INTO "topics"("topic_name")
SELECT DISTINCT topic
FROM "bad_posts";

INSERT INTO "posts"("user_id",
                    "topic_id",
                    "url",
                    "text_content",
                    "title")
SELECT u.id,
top.id,
bad.url,
bad.text_content,
LEFT(bad.title,100)
FROM "bad_posts" bad
    LEFT JOIN "users" u
        ON bad.username = u.username
    LEFT JOIN "topics" top
        ON "bad".topic = top.topic_name;

INSERT INTO "comments" (
    "user_id",
    "text_content",
    "post_id")
SELECT u.id, badc.text_content, p.id
FROM "bad_comments" badc
LEFT JOIN users u
    ON u.username = badc.username
LEFT JOIN posts p
    ON p.id = badc.post_id;

INSERT INTO "votes" ("user_id", "post_id", "vote")
WITH downvotes_ AS (SELECT id, REGEXP_SPLIT_TO_TABLE(downvotes, ',') AS downvote
FROM "bad_posts")
SELECT u.id, downvotes_.id, -1 AS vote
FROM downvotes_
JOIN "users" u
ON u.username = downvotes_.downvote;

INSERT INTO "votes" ("user_id", "post_id", "vote")
WITH upvotes_ AS (SELECT id, REGEXP_SPLIT_TO_TABLE(upvotes, ',') AS upvote
FROM "bad_posts")
SELECT u.id, upvotes_.id, 1 AS vote
FROM upvotes_
JOIN "users" u
ON u.username = upvotes_.upvote;
