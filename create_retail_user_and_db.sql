create database retail_db;

create user retail_user with encrypted password 'admin';

grant all on database retail_db to retail_user;

