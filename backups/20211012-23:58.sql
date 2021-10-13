--
-- PostgreSQL database dump
--

-- Dumped from database version 13.4 (Debian 13.4-4.pgdg110+1)
-- Dumped by pg_dump version 13.4 (Debian 13.4-4.pgdg110+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: letras; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.letras (
    letra character(1) NOT NULL
);


ALTER TABLE public.letras OWNER TO postgres;

--
-- Data for Name: letras; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.letras (letra) FROM stdin;
a
b
c
d
e
\.


--
-- Name: letras letras_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.letras
    ADD CONSTRAINT letras_pkey PRIMARY KEY (letra);


--
-- PostgreSQL database dump complete
--

