# Use an official Node.js runtime
FROM node:18-alpine

# Set the working directory in the container
WORKDIR /app

# Copy package.json and install dependencies
COPY package*.json ./
RUN npm install

# Copy the rest of the app's source code
COPY . .

# Make port 8080 available
EXPOSE 8080

# Define the command to run the app
CMD [ "npm", "start" ]