<?php
// phpcs:disable

/**
 * Route matrix fixture for PHP route extraction tests.
 *
 * @category Fixture
 * @package Scout
 * @author Scout
 * @license MIT
 * @link https://example.invalid/scout-fixture
 */

if (function_exists('register_rest_route')) {
    register_rest_route('my/v1', '/items/:id', array());
}

$note = '/items/example';
// phpcs:enable
