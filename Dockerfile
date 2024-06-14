# Use the official Nginx base image
FROM nginx:alpine

# Copy custom configuration file
COPY index.html /etc/nginx/nginx.conf

# Copy static HTML files to serve
COPY html /usr/share/nginx/html

# Expose ports
EXPOSE 80

# Start Nginx server
CMD ["nginx", "-g", "daemon off;"]
