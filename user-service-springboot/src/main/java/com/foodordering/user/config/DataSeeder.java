package com.foodordering.user.config;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

import com.foodordering.user.model.User;
import com.foodordering.user.model.UserRole;
import com.foodordering.user.repository.UserRepository;

import java.time.LocalDateTime;

/**
 * Data seeder to initialize the database with default data
 */
@Component
public class DataSeeder implements CommandLineRunner {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Override
    public void run(String... args) throws Exception {
        seedAdminUser();
    }

    private void seedAdminUser() {
        // Check if admin user exists
        if (userRepository.countByRole(UserRole.ADMIN.name()) == 0) {
            User admin = new User();
            admin.setEmail("admin@foodordering.com");
            admin.setPassword(passwordEncoder.encode("AdminPass123!"));
            admin.setName("System Administrator");
            admin.setRole(UserRole.ADMIN.name());
            admin.setPhone("+1234567890");
            admin.setCreatedAt(LocalDateTime.now());
            admin.setUpdatedAt(LocalDateTime.now());
            admin.setEmailVerified(true);

            userRepository.save(admin);
            System.out.println("✅ Default admin user created: admin@foodordering.com");
        }
    }
}
