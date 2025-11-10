# Dockerfile

# --- Stage 1: Build the React App ---
# Use an official Node.js image as the base
FROM node:20-alpine AS build

# Set the working directory
WORKDIR /app

# Copy package.json and package-lock.json
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy the rest of the application source code
COPY . .

# Build the app for production
# The output will be in the /app/dist folder
RUN npm run build

# --- Stage 2: Serve the App with Nginx ---
# Use a lightweight Nginx image
FROM nginx:alpine

# Copy the build output from Stage 1
# Copy from the 'build' stage's /app/dist folder...
# ...to Nginx's public HTML folder.
COPY --from=build /app/dist /usr/share/nginx/html

# Nginx listens on port 80 by default
EXPOSE 80

# The default Nginx command will run, serving the static files
